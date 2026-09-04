import SwiftUI
import SwiftData

/// Edit a category: name, color, blueprint quantity, and its exercise stack.
struct CategoryDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var category: WorkoutCategory

    @State private var newExerciseName = ""

    private var sortedExercises: [Exercise] {
        category.exercises.lruSorted()
    }

    var body: some View {
        Form {
            Section("Category") {
                TextField("Name", text: $category.name)
                ColorPalettePicker(selection: $category.colorHex)
                TileCountField(count: $category.blueprintCount)
            }

            Section {
                ForEach(sortedExercises) { exercise in
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                Text(exercise.lastPerformedLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(exercise.tracking == .untracked
                                 ? exercise.tracking.label
                                 : exercise.lastValueLabel)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteExercises)

                HStack {
                    TextField("New exercise name", text: $newExerciseName)
                        .onSubmit(addExercise)
                    Button(action: addExercise) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Exercises")
            } footer: {
                Text("Sorted least recently used first — the same order as in the workout picker. Tap an exercise to set what it tracks and see its full history.")
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addExercise() {
        let name = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        context.insert(Exercise(name: name, category: category))
        try? context.save()
        newExerciseName = ""
    }

    private func deleteExercises(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sortedExercises[index])
        }
        try? context.save()
    }
}
