import SwiftUI
import SwiftData

/// The modal shown when a category tile is tapped: the category's exercises
/// strictly LRU-sorted, with the previous value next to each name.
struct ExercisePickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let task: CycleTask
    /// Called when the user confirms a value; the caller completes the tile
    /// after the sheet is dismissed.
    let onLog: (Exercise, Double?) -> Void

    @State private var newExerciseName = ""

    private var category: WorkoutCategory? { task.category }

    private var sortedExercises: [Exercise] {
        (category?.exercises ?? []).filter { !$0.isDeleted }.lruSorted()
    }

    var body: some View {
        NavigationStack {
            List {
                if sortedExercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises Yet",
                        systemImage: "list.bullet",
                        description: Text("Add your first \(category?.name ?? "") exercise below.")
                    )
                } else {
                    Section {
                        ForEach(Array(sortedExercises.enumerated()), id: \.element.id) { index, exercise in
                            if exercise.tracking == .untracked {
                                // Nothing to enter — one tap logs it.
                                Button {
                                    onLog(exercise, nil)
                                } label: {
                                    ExerciseRow(exercise: exercise, isUpNext: index == 0)
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    LogValueView(exercise: exercise) { value in
                                        onLog(exercise, value)
                                    }
                                } label: {
                                    ExerciseRow(exercise: exercise, isUpNext: index == 0)
                                }
                            }
                        }
                    } footer: {
                        Text("Sorted by least recently performed — pick the top one to keep your rotation balanced.")
                    }
                }

                Section {
                    HStack {
                        TextField("New exercise name", text: $newExerciseName)
                            .onSubmit(addExercise)
                        Button(action: addExercise) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } footer: {
                    Text("New exercises track weight in kg by default — change that in Settings → program → category → exercise.")
                }
            }
            .navigationTitle(category?.name ?? "Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func addExercise() {
        let name = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let category else { return }
        context.insert(Exercise(name: name, category: category))
        try? context.save()
        newExerciseName = ""
    }
}

struct ExerciseRow: View {
    let exercise: Exercise
    let isUpNext: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.body.weight(.medium))
                    if isUpNext {
                        Text("UP NEXT")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(exercise.lastPerformedLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if exercise.tracking == .untracked {
                // Hints that tapping completes it straight away.
                Image(systemName: "checkmark.circle")
                    .font(.title3)
                    .foregroundStyle(.tint)
            } else {
                Text(exercise.lastValueLabel)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(exercise.lastValue == nil ? .secondary : .primary)
            }
        }
        .padding(.vertical, 2)
    }
}
