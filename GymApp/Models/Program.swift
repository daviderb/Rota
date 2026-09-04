import Foundation
import SwiftData

/// An independent cycle system (e.g. "Workout", "Stretching"). Each program
/// owns its own categories, blueprint, active cycle and history, so finishing
/// a stretching exercise never satisfies a workout tile.
@Model
final class Program {
    var name: String
    var iconName: String
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \WorkoutCategory.program)
    var categories: [WorkoutCategory] = []

    @Relationship(deleteRule: .cascade, inverse: \CycleTask.program)
    var tasks: [CycleTask] = []

    @Relationship(deleteRule: .cascade, inverse: \CycleRecord.program)
    var cycles: [CycleRecord] = []

    init(name: String, iconName: String = "dumbbell.fill", sortOrder: Int = 0) {
        self.name = name
        self.iconName = iconName
        self.sortOrder = sortOrder
    }
}

extension Program {
    var sortedCategories: [WorkoutCategory] {
        categories.filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// How many tiles one full cycle of this program contains.
    var tilesPerCycle: Int {
        sortedCategories.reduce(0) { $0 + max(0, $1.blueprintCount) }
    }
}

/// SF Symbols offered when creating or editing a program.
enum ProgramIcon {
    static let symbols: [String] = [
        "dumbbell.fill",
        "figure.strengthtraining.traditional",
        "figure.flexibility",
        "figure.cooldown",
        "figure.core.training",
        "figure.mind.and.body",
        "figure.run",
        "figure.pool.swim",
        "heart.fill",
        "leaf.fill",
        "bolt.fill",
        "moon.stars.fill",
    ]
}
