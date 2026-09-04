import Foundation
import SwiftData

/// First-launch example data matching the blueprint from the spec
/// (2 Push / 2 Pull / 2 Hinge / 2 Squat). Everything is editable in Settings.
enum SeedData {
    private static let seededKey = "didSeedDefaultData"

    static func seedIfNeeded(in context: ModelContext, force: Bool = false) {
        let categoryCount = (try? context.fetchCount(FetchDescriptor<WorkoutCategory>())) ?? 0
        let programCount = (try? context.fetchCount(FetchDescriptor<Program>())) ?? 0
        guard categoryCount == 0, programCount == 0 else { return }
        if !force {
            // The flag keeps us from re-seeding if the user deliberately deletes everything.
            guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        }

        let program = Program(name: "Workout", iconName: "dumbbell.fill", sortOrder: 0)
        context.insert(program)

        let blueprint: [(name: String, hex: String, exercises: [String])] = [
            ("Push", "FF6B5E", ["Bench Press", "Overhead Press", "Incline Dumbbell Press"]),
            ("Pull", "42A5F5", ["Pull-Ups", "Barbell Row", "Lat Pulldown"]),
            ("Hinge", "AB47BC", ["Deadlift", "Romanian Deadlift", "Hip Thrust"]),
            ("Squat", "9CCC65", ["Back Squat", "Front Squat", "Bulgarian Split Squat"]),
        ]

        for (index, entry) in blueprint.enumerated() {
            let category = WorkoutCategory(
                name: entry.name,
                colorHex: entry.hex,
                blueprintCount: 2,
                sortOrder: index,
                program: program
            )
            context.insert(category)
            for exerciseName in entry.exercises {
                context.insert(Exercise(name: exerciseName, category: category))
            }
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    /// Moves data created before programs existed into a single default
    /// program, so existing categories, cycles and logs survive the upgrade.
    static func migrateToProgramsIfNeeded(in context: ModelContext) {
        let categories = ((try? context.fetch(FetchDescriptor<WorkoutCategory>())) ?? [])
            .filter { !$0.isDeleted && $0.program == nil }
        let tasks = ((try? context.fetch(FetchDescriptor<CycleTask>())) ?? [])
            .filter { !$0.isDeleted && $0.program == nil }
        let records = ((try? context.fetch(FetchDescriptor<CycleRecord>())) ?? [])
            .filter { !$0.isDeleted && $0.program == nil }

        guard !categories.isEmpty || !tasks.isEmpty || !records.isEmpty else { return }

        let existing = ((try? context.fetch(FetchDescriptor<Program>())) ?? [])
            .filter { !$0.isDeleted }
            .sorted { $0.sortOrder < $1.sortOrder }

        let target: Program
        if let first = existing.first {
            target = first
        } else {
            target = Program(name: "Workout", iconName: "dumbbell.fill", sortOrder: 0)
            context.insert(target)
        }

        for category in categories { category.program = target }
        for task in tasks where task.program == nil {
            task.program = task.category?.program ?? target
        }
        for record in records { record.program = target }
        try? context.save()
    }
}
