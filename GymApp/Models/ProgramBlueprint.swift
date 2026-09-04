import Foundation
import SwiftData

/// A shareable snapshot of what a program *contains* — categories, their
/// exercises and the blueprint counts. Deliberately carries no history and no
/// cycle progress, so importing gives the recipient a clean start.
struct ProgramBlueprint: Codable {
    var formatVersion: Int = 1
    var name: String
    var icon: String
    var categories: [CategoryBlueprint]

    struct CategoryBlueprint: Codable {
        var name: String
        var color: String
        var tilesPerCycle: Int
        var exercises: [ExerciseBlueprint]
    }

    struct ExerciseBlueprint: Codable {
        var name: String
        var track: String
        var unit: String
        var step: Double
    }
}

// MARK: - Export

extension ProgramBlueprint {
    init(program: Program) {
        self.name = program.name
        self.icon = program.iconName
        self.categories = program.sortedCategories.map { category in
            CategoryBlueprint(
                name: category.name,
                color: category.colorHex,
                tilesPerCycle: category.blueprintCount,
                exercises: category.exercises
                    .filter { !$0.isDeleted }
                    .sorted { $0.name < $1.name }
                    .map { exercise in
                        ExerciseBlueprint(
                            name: exercise.name,
                            track: exercise.tracking.rawValue,
                            unit: exercise.unitLabel,
                            step: exercise.step
                        )
                    }
            )
        }
    }

    /// Pretty-printed JSON — readable enough to paste into a message.
    func encoded() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
}

// MARK: - Import

enum BlueprintImportError: LocalizedError {
    case notJSON
    case unsupportedVersion(Int)
    case empty

    var errorDescription: String? {
        switch self {
        case .notJSON:
            "That doesn't look like a GymApp program. Paste the whole text you were sent, including the { and } braces."
        case .unsupportedVersion(let version):
            "This program was exported by a newer version of GymApp (format \(version))."
        case .empty:
            "That program has no categories in it."
        }
    }
}

extension ProgramBlueprint {
    static func decoded(from text: String) throws -> ProgramBlueprint {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let blueprint = try? JSONDecoder().decode(ProgramBlueprint.self, from: data)
        else { throw BlueprintImportError.notJSON }

        guard blueprint.formatVersion <= 1 else {
            throw BlueprintImportError.unsupportedVersion(blueprint.formatVersion)
        }
        guard !blueprint.categories.isEmpty else { throw BlueprintImportError.empty }
        return blueprint
    }

    var exerciseCount: Int {
        categories.reduce(0) { $0 + $1.exercises.count }
    }

    var tilesPerCycle: Int {
        categories.reduce(0) { $0 + max(0, $1.tilesPerCycle) }
    }

    /// Creates a fresh program from this blueprint. Values coming from another
    /// device are sanitised — unknown icons, colors and units fall back to
    /// valid ones rather than producing a broken program.
    @discardableResult
    func makeProgram(in context: ModelContext) -> Program {
        let existing = ((try? context.fetch(FetchDescriptor<Program>())) ?? []).filter { !$0.isDeleted }
        let program = Program(
            name: Self.uniqueName(from: name, existing: existing.map(\.name)),
            iconName: ProgramIcon.symbols.contains(icon) ? icon : ProgramIcon.symbols[0],
            sortOrder: (existing.map(\.sortOrder).max() ?? -1) + 1
        )
        context.insert(program)

        for (index, category) in categories.enumerated() {
            let workoutCategory = WorkoutCategory(
                name: category.name.trimmingCharacters(in: .whitespaces),
                colorHex: Self.sanitizedColor(category.color, fallbackIndex: index),
                blueprintCount: max(0, min(category.tilesPerCycle, 999)),
                sortOrder: index,
                program: program
            )
            context.insert(workoutCategory)

            for entry in category.exercises {
                let mode = TrackingMode(rawValue: entry.track) ?? .weight
                let exercise = Exercise(
                    name: entry.name.trimmingCharacters(in: .whitespaces),
                    category: workoutCategory,
                    tracking: mode
                )
                if mode.units.contains(entry.unit) {
                    exercise.unitLabel = entry.unit
                }
                if entry.step > 0 {
                    exercise.step = entry.step
                }
                context.insert(exercise)
            }
        }
        try? context.save()
        return program
    }

    /// "Workout" → "Workout 2" when the name is already taken.
    private static func uniqueName(from name: String, existing: [String]) -> String {
        let base = name.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Imported Program"
            : name.trimmingCharacters(in: .whitespaces)
        guard existing.contains(base) else { return base }
        var suffix = 2
        while existing.contains("\(base) \(suffix)") { suffix += 1 }
        return "\(base) \(suffix)"
    }

    private static func sanitizedColor(_ hex: String, fallbackIndex: Int) -> String {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
        let isValid = cleaned.count == 6 && cleaned.allSatisfy(\.isHexDigit)
        return isValid ? cleaned : Palette.hexes[fallbackIndex % Palette.hexes.count]
    }
}
