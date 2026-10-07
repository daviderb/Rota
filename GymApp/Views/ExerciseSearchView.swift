import SwiftUI
import SwiftData

/// One exercise found by search: where it lives, and whether its tile is
/// still on the board in the current cycle.
struct ExerciseSearchResult: Identifiable {
    let exercise: Exercise
    /// Outstanding tiles of the exercise's category, oldest first.
    let openTasks: [CycleTask]
    let rank: Int

    var id: PersistentIdentifier { exercise.persistentModelID }
    var category: WorkoutCategory? { exercise.category }
    var program: Program? { exercise.category?.program }
    var remaining: Int { openTasks.count }
    var nextTask: CycleTask? { openTasks.first }
}

enum ExerciseSearch {
    /// Searches every program. Exercises whose own name matches rank first
    /// (prefix before substring); typing a category or program name lists
    /// everything inside it after those.
    static func results(for query: String, exercises: [Exercise], tasks: [CycleTask]) -> [ExerciseSearchResult] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let openTasks = tasks.filter { !$0.isDeleted }

        return exercises.compactMap { exercise -> ExerciseSearchResult? in
            guard !exercise.isDeleted, let category = exercise.category, !category.isDeleted else { return nil }

            let rank: Int
            if matches(exercise.name, query, anchored: true) {
                rank = 0
            } else if matches(exercise.name, query) {
                rank = 1
            } else if matches(category.name, query) || matches(category.program?.name ?? "", query) {
                rank = 2
            } else {
                return nil
            }

            let tilesForCategory = openTasks
                .filter { $0.category?.persistentModelID == category.persistentModelID }
                .sorted { $0.createdAt < $1.createdAt }
            return ExerciseSearchResult(exercise: exercise, openTasks: tilesForCategory, rank: rank)
        }
        .sorted { ($0.rank, $0.exercise.name.localizedLowercase) < ($1.rank, $1.exercise.name.localizedLowercase) }
    }

    /// Case- and accent-insensitive, so "ruck" finds "Rück…" and vice versa.
    private static func matches(_ text: String, _ query: String, anchored: Bool = false) -> Bool {
        var options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        if anchored { options.insert(.anchored) }
        return text.range(of: query, options: options) != nil
    }
}

/// Replaces the tile grid while a search is active.
struct ExerciseSearchResultsView: View {
    let query: String
    let results: [ExerciseSearchResult]
    let showsProgram: Bool
    let onSelect: (ExerciseSearchResult) -> Void

    var body: some View {
        if results.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List {
                Section {
                    ForEach(results) { result in
                        if result.nextTask != nil {
                            Button {
                                onSelect(result)
                            } label: {
                                ExerciseSearchRow(result: result, showsProgram: showsProgram)
                            }
                            .buttonStyle(.plain)
                        } else {
                            ExerciseSearchRow(result: result, showsProgram: showsProgram)
                        }
                    }
                } footer: {
                    Text("Tap an exercise whose tile is still on the board to log it.")
                }
            }
        }
    }
}

struct ExerciseSearchRow: View {
    let result: ExerciseSearchResult
    let showsProgram: Bool

    private var isAvailable: Bool { result.remaining > 0 }

    var body: some View {
        HStack(spacing: 12) {
            // A miniature of the tile on the main grid, so the answer to
            // "which tile?" is recognisable at a glance.
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(result.category?.color ?? .gray)
                .frame(width: 34, height: 34)
                .overlay {
                    if result.remaining > 1 {
                        Text("\(result.remaining)")
                            .font(.caption.bold())
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: result.program?.iconName ?? "dumbbell.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
                .opacity(isAvailable ? 1 : 0.35)

            VStack(alignment: .leading, spacing: 3) {
                Text(result.exercise.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isAvailable ? .primary : .secondary)
                Text(locationLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !result.exercise.lastValueLabel.isEmpty {
                Text(result.exercise.lastValueLabel)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if isAvailable {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// "Push tile · 2 left", "Stretching › Hips tile · done this cycle", …
    private var locationLabel: String {
        let categoryName = result.category?.name ?? "No category"
        let place = showsProgram
            ? "\(result.program?.name ?? "") › \(categoryName) tile"
            : "\(categoryName) tile"

        if result.remaining > 0 {
            return "\(place) · \(result.remaining) left"
        }
        if (result.category?.blueprintCount ?? 0) == 0 {
            return "\(place) · not part of the cycle"
        }
        return "\(place) · done this cycle"
    }
}
