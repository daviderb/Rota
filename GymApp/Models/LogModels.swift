import Foundation
import SwiftData

/// One historical (or currently running) cycle. `completedAt == nil` means
/// it's the active cycle; `wasRestarted` marks cycles ended early via
/// "Restart Cycle Now" in Settings.
@Model
final class CycleRecord {
    var number: Int
    var startedAt: Date
    var completedAt: Date?
    var wasRestarted: Bool
    var program: Program?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutLogEntry.cycle)
    var entries: [WorkoutLogEntry] = []

    init(number: Int, program: Program? = nil, startedAt: Date = .now) {
        self.number = number
        self.program = program
        self.startedAt = startedAt
        self.wasRestarted = false
    }
}

extension CycleRecord {
    var sortedEntries: [WorkoutLogEntry] {
        entries.filter { !$0.isDeleted }.sorted { $0.performedAt < $1.performedAt }
    }

    /// "Completed in 2 d 5 h" / "Restarted after 3 h 12 min" / "In progress…"
    var statusLabel: String {
        if let completedAt {
            let duration = formattedDuration(from: startedAt, to: completedAt)
            return wasRestarted ? "Restarted after \(duration)" : "Completed in \(duration)"
        }
        return "In progress — started \(formattedDuration(from: startedAt, to: .now)) ago"
    }
}

/// One logged set of an exercise. Name and category are stored as snapshots
/// so the log stays intact if exercises or categories are renamed or deleted;
/// the `exercise` link powers the per-exercise history view.
@Model
final class WorkoutLogEntry {
    var performedAt: Date
    /// The logged value, in `unitLabel`. Stored under its original name so
    /// existing databases keep their history through the upgrade.
    var weight: Double?
    var exerciseName: String
    var categoryName: String
    /// Snapshot of the unit at logging time, so changing an exercise's unit
    /// later doesn't silently relabel old entries. `nil` reads as "kg".
    var unit: String?
    var exercise: Exercise?
    var cycle: CycleRecord?

    init(exercise: Exercise, weight: Double?, performedAt: Date = .now, cycle: CycleRecord? = nil) {
        self.performedAt = performedAt
        self.weight = weight
        self.exerciseName = exercise.name
        self.categoryName = exercise.category?.name ?? ""
        self.unit = exercise.tracking == .untracked ? "" : exercise.unitLabel
        self.exercise = exercise
        self.cycle = cycle
    }
}

extension WorkoutLogEntry {
    var value: Double? {
        get { weight }
        set { weight = newValue }
    }

    var unitLabel: String { unit ?? "kg" }

    /// "80 kg", "45 s", "done" for untracked, "—" when nothing was entered.
    var valueLabel: String {
        guard let value else { return unitLabel.isEmpty ? "done" : "—" }
        return unitLabel.isEmpty ? value.valueFormatted : "\(value.valueFormatted) \(unitLabel)"
    }
}

/// "2 d 5 h", "3 h 12 min", "8 min"
func formattedDuration(from start: Date, to end: Date) -> String {
    let seconds = max(0, Int(end.timeIntervalSince(start)))
    let days = seconds / 86400
    let hours = (seconds % 86400) / 3600
    let minutes = (seconds % 3600) / 60
    if days > 0 { return "\(days) d \(hours) h" }
    if hours > 0 { return "\(hours) h \(minutes) min" }
    return "\(minutes) min"
}
