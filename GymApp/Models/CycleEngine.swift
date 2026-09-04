import Foundation
import SwiftData

/// Pure logic for the asynchronous cycle system. Every operation is scoped to
/// a single `Program`, so programs never interfere with each other.
enum CycleEngine {

    // MARK: - Active cycle

    /// Outstanding tiles of one program.
    /// Fetching (rather than reading `program.tasks`) reflects unsaved
    /// deletions made earlier in the same context.
    static func tasks(for program: Program, in context: ModelContext) -> [CycleTask] {
        let all = (try? context.fetch(FetchDescriptor<CycleTask>())) ?? []
        return all.filter { !$0.isDeleted && $0.program?.persistentModelID == program.persistentModelID }
    }

    static func remainingTaskCount(for program: Program, in context: ModelContext) -> Int {
        tasks(for: program, in: context).count
    }

    /// Populates a program's cycle from its blueprint if it is currently empty.
    static func repopulateIfEmpty(for program: Program, in context: ModelContext) {
        guard remainingTaskCount(for: program, in: context) == 0 else { return }
        repopulate(for: program, in: context)
    }

    /// Gives every program a running cycle — used on launch and whenever
    /// programs or blueprints may have changed.
    static func repopulateAllIfEmpty(in context: ModelContext) {
        let programs = (try? context.fetch(FetchDescriptor<Program>())) ?? []
        for program in programs where !program.isDeleted {
            repopulateIfEmpty(for: program, in: context)
        }
    }

    /// Discards a program's remaining tiles and starts a fresh cycle from its
    /// blueprint. A cycle that already has logged exercises is kept in the log
    /// and marked as restarted; an untouched one is replaced silently.
    static func repopulate(for program: Program, in context: ModelContext) {
        if let open = openCycleRecord(for: program, in: context) {
            if open.sortedEntries.isEmpty {
                context.delete(open)
            } else {
                open.completedAt = .now
                open.wasRestarted = true
            }
        }

        for task in tasks(for: program, in: context) {
            context.delete(task)
        }

        var createdTiles = false
        for category in program.sortedCategories {
            for _ in 0..<max(0, category.blueprintCount) {
                context.insert(CycleTask(category: category, program: program))
                createdTiles = true
            }
        }
        if createdTiles {
            context.insert(CycleRecord(number: nextCycleNumber(for: program, in: context), program: program))
        }
        try? context.save()
    }

    /// Logs `exercise` against a tile: stamps it with now + the new value
    /// (sending it to the bottom of the LRU stack), writes a log entry, and
    /// removes the tile. Completing the last tile closes the cycle record.
    static func complete(task: CycleTask, exercise: Exercise, value: Double?, in context: ModelContext) {
        let program = task.program ?? task.category?.program
        exercise.lastValue = value
        exercise.lastPerformedAt = .now

        let record = program.flatMap { activeCycleRecord(for: $0, in: context) }
        context.insert(WorkoutLogEntry(exercise: exercise, weight: value, cycle: record))

        context.delete(task)
        if let program, remainingTaskCount(for: program, in: context) == 0 {
            record?.completedAt = .now
        }
        try? context.save()
    }

    /// Re-derives an exercise's `lastWeight`/`lastPerformedAt` from its log,
    /// so editing or deleting log entries keeps the LRU stack and the
    /// displayed previous weight consistent.
    static func syncFromLog(exercise: Exercise, in context: ModelContext) {
        let entries = exercise.logEntries.filter { !$0.isDeleted }
        // No entries left: keep the existing stamp (it may predate logging).
        guard let latest = entries.max(by: { $0.performedAt < $1.performedAt }) else { return }
        exercise.lastWeight = latest.weight
        exercise.lastPerformedAt = latest.performedAt
        try? context.save()
    }

    // MARK: - Cycle records

    static func records(for program: Program, in context: ModelContext) -> [CycleRecord] {
        let all = (try? context.fetch(FetchDescriptor<CycleRecord>())) ?? []
        return all.filter { !$0.isDeleted && $0.program?.persistentModelID == program.persistentModelID }
    }

    private static func openCycleRecord(for program: Program, in context: ModelContext) -> CycleRecord? {
        records(for: program, in: context).first { $0.completedAt == nil }
    }

    /// The record for the cycle in progress, created on the fly when tiles
    /// exist without an open record (e.g. after the log was edited).
    private static func activeCycleRecord(for program: Program, in context: ModelContext) -> CycleRecord? {
        if let open = openCycleRecord(for: program, in: context) { return open }
        let tiles = tasks(for: program, in: context)
        guard !tiles.isEmpty else { return nil }
        let record = CycleRecord(
            number: nextCycleNumber(for: program, in: context),
            program: program,
            startedAt: tiles.map(\.createdAt).min() ?? .now
        )
        context.insert(record)
        return record
    }

    /// Cycle numbers run independently per program.
    static func nextCycleNumber(for program: Program, in context: ModelContext) -> Int {
        (records(for: program, in: context).map(\.number).max() ?? 0) + 1
    }
}
