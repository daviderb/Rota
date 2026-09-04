import Foundation
import SwiftData
import SwiftUI

/// A muscle group / movement pattern (e.g. Push, Pull, Hinge, Squat).
/// `blueprintCount` doubles as the cycle blueprint: how many tiles of this
/// category make up one fresh cycle.
@Model
final class WorkoutCategory {
    var name: String
    var colorHex: String
    var blueprintCount: Int
    var sortOrder: Int
    var program: Program?

    @Relationship(deleteRule: .cascade, inverse: \Exercise.category)
    var exercises: [Exercise] = []

    @Relationship(deleteRule: .cascade, inverse: \CycleTask.category)
    var cycleTasks: [CycleTask] = []

    init(name: String, colorHex: String, blueprintCount: Int = 1, sortOrder: Int = 0, program: Program? = nil) {
        self.name = name
        self.colorHex = colorHex
        self.blueprintCount = blueprintCount
        self.sortOrder = sortOrder
        self.program = program
    }

    var color: Color { Color(hex: colorHex) }
}

/// A specific movement. `lastPerformedAt` drives the LRU rotation,
/// `lastWeight` drives progressive overload display.
@Model
final class Exercise {
    var name: String
    /// The value logged last time, in `unitLabel`. Stored under its original
    /// name so existing databases keep their history through the upgrade.
    var lastWeight: Double?
    var lastPerformedAt: Date?
    var category: WorkoutCategory?

    // Tracking configuration. Optional so older stores migrate cleanly;
    // `nil` reads as the previous behaviour (weight in kg).
    var trackingRaw: String?
    var unit: String?
    var stepSize: Double?

    // Log entries survive the exercise being deleted (they keep name snapshots).
    @Relationship(deleteRule: .nullify, inverse: \WorkoutLogEntry.exercise)
    var logEntries: [WorkoutLogEntry] = []

    init(name: String, category: WorkoutCategory? = nil, tracking: TrackingMode = .weight) {
        self.name = name
        self.category = category
        self.trackingRaw = tracking.rawValue
        self.unit = tracking.defaultUnit
        self.stepSize = tracking.defaultStep(for: tracking.defaultUnit)
    }
}

extension Exercise {
    /// What this exercise records: nothing, weight, time, reps or distance.
    var tracking: TrackingMode {
        get { TrackingMode(rawValue: trackingRaw ?? "") ?? .weight }
        set {
            trackingRaw = newValue.rawValue
            // Carry over the unit only if it still makes sense for the new mode.
            if !newValue.units.contains(unitLabel) {
                unit = newValue.defaultUnit
                stepSize = newValue.defaultStep(for: newValue.defaultUnit)
            }
        }
    }

    var unitLabel: String {
        get { unit ?? tracking.defaultUnit }
        set {
            unit = newValue
            stepSize = tracking.defaultStep(for: newValue)
        }
    }

    /// Increment used by the −/+ buttons on the logging screen.
    var step: Double {
        get { stepSize ?? tracking.defaultStep(for: unitLabel) }
        set { stepSize = newValue }
    }

    var lastValue: Double? {
        get { lastWeight }
        set { lastWeight = newValue }
    }

    /// "80 kg", "45 s", "—", or empty for untracked exercises.
    var lastValueLabel: String {
        guard tracking != .untracked else { return "" }
        guard let lastValue else { return "—" }
        return "\(lastValue.valueFormatted) \(unitLabel)"
    }

    var lastPerformedLabel: String {
        guard let lastPerformedAt else { return "Never performed" }
        return "Last done \(lastPerformedAt.formatted(.relative(presentation: .named)))"
    }
}

/// What an exercise records when it is logged.
enum TrackingMode: String, CaseIterable, Identifiable {
    case untracked
    case weight
    case duration
    case reps
    case distance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .untracked: "Nothing"
        case .weight: "Weight"
        case .duration: "Time"
        case .reps: "Reps"
        case .distance: "Distance"
        }
    }

    var units: [String] {
        switch self {
        case .untracked: []
        case .weight: ["kg", "lb"]
        case .duration: ["s", "min"]
        case .reps: ["reps"]
        case .distance: ["m", "km", "mi"]
        }
    }

    var defaultUnit: String { units.first ?? "" }

    func defaultStep(for unit: String) -> Double {
        switch (self, unit) {
        case (.untracked, _): 0
        case (.weight, "lb"): 5
        case (.weight, _): 2.5
        case (.duration, "min"): 1
        case (.duration, _): 15
        case (.reps, _): 1
        case (.distance, "km"): 0.5
        case (.distance, "mi"): 0.25
        case (.distance, _): 100
        }
    }
}

/// One remaining tile of the active cycle. The set of all `CycleTask` rows
/// *is* the active cycle; when the last one is deleted the cycle is complete
/// and gets repopulated from the blueprint.
@Model
final class CycleTask {
    var createdAt: Date
    var category: WorkoutCategory?
    var program: Program?

    init(category: WorkoutCategory, program: Program? = nil) {
        self.createdAt = .now
        self.category = category
        self.program = program ?? category.program
    }
}

extension Array where Element == Exercise {
    /// Least recently used first: never-performed exercises lead (alphabetical),
    /// then oldest `lastPerformedAt` to newest.
    func lruSorted() -> [Exercise] {
        sorted { lhs, rhs in
            switch (lhs.lastPerformedAt, rhs.lastPerformedAt) {
            case (nil, nil): return lhs.name < rhs.name
            case (nil, _): return true
            case (_, nil): return false
            case let (l?, r?): return l < r
            }
        }
    }
}

extension Double {
    /// "62.5", "80" — for display next to a unit.
    var valueFormatted: String {
        formatted(.number.precision(.fractionLength(0...2)))
    }

    /// Plain dot-decimal string for pre-filling the weight text field.
    var editingString: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self)
    }
}
