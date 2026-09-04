import SwiftUI
import SwiftData

/// Edit a single log entry (names are snapshots, so edits never touch the
/// exercise itself — except that the linked exercise's "previous weight" and
/// LRU position are re-synced from its latest entry).
struct LogEntryEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let entry: WorkoutLogEntry

    @State private var exerciseName: String
    @State private var categoryName: String
    @State private var weightText: String
    @State private var performedAt: Date

    /// Seeded in `init` rather than `onAppear` so the fields show the entry's
    /// real values on the very first render.
    init(entry: WorkoutLogEntry) {
        self.entry = entry
        _exerciseName = State(initialValue: entry.exerciseName)
        _categoryName = State(initialValue: entry.categoryName)
        _weightText = State(initialValue: entry.value?.editingString ?? "")
        _performedAt = State(initialValue: entry.performedAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Exercise name", text: $exerciseName)
                    TextField("Category name", text: $categoryName)
                }
                Section("Log") {
                    HStack {
                        TextField(entry.unitLabel.isEmpty ? "No value tracked" : "Value (leave empty for none)", text: $weightText)
                            .keyboardType(.decimalPad)
                        Text(entry.unitLabel)
                            .foregroundStyle(.secondary)
                    }
                    DatePicker("Performed", selection: $performedAt)
                }
            }
            .navigationTitle("Edit Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        entry.exerciseName = exerciseName.trimmingCharacters(in: .whitespaces)
        entry.categoryName = categoryName.trimmingCharacters(in: .whitespaces)
        entry.value = Double(weightText.replacingOccurrences(of: ",", with: "."))
        entry.performedAt = performedAt
        if let exercise = entry.exercise {
            CycleEngine.syncFromLog(exercise: exercise, in: context)
        }
        try? context.save()
        dismiss()
    }
}
