import SwiftUI
import SwiftData

/// Edit a cycle record: its number, when it started, and whether/when it
/// finished. Cycle numbers are per-program, so two programs can both have a
/// "Cycle 3" without clashing.
struct CycleEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let cycle: CycleRecord

    @State private var number: Int
    @State private var startedAt: Date
    @State private var isCompleted: Bool
    @State private var completedAt: Date
    @State private var wasRestarted: Bool
    @State private var confirmDelete = false

    /// Seeded in `init` rather than `onAppear` so the fields show the cycle's
    /// real values on the very first render.
    init(cycle: CycleRecord) {
        self.cycle = cycle
        _number = State(initialValue: cycle.number)
        _startedAt = State(initialValue: cycle.startedAt)
        _isCompleted = State(initialValue: cycle.completedAt != nil)
        _completedAt = State(initialValue: cycle.completedAt ?? cycle.startedAt)
        _wasRestarted = State(initialValue: cycle.wasRestarted)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cycle") {
                    Stepper("Cycle number: \(number)", value: $number, in: 1...9999)
                    DatePicker("Started", selection: $startedAt)
                }

                Section {
                    Toggle("Completed", isOn: $isCompleted)
                    if isCompleted {
                        // Unbounded: an out-of-range bound would trap. The
                        // finish date is clamped to the start date on save.
                        DatePicker("Finished", selection: $completedAt)
                        Toggle("Ended by restart", isOn: $wasRestarted)
                    }
                } footer: {
                    Text(isCompleted
                         ? "Turning this off makes it the running cycle again."
                         : "This is the cycle currently in progress.")
                }

                Section {
                    Button("Delete Cycle", role: .destructive) { confirmDelete = true }
                } footer: {
                    Text("Deleting a cycle also deletes the \(cycle.sortedEntries.count) log entr\(cycle.sortedEntries.count == 1 ? "y" : "ies") inside it.")
                }
            }
            .navigationTitle("Edit Cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                }
            }
            .confirmationDialog("Delete Cycle \(cycle.number)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete Cycle", role: .destructive) { delete() }
            } message: {
                Text("This cannot be undone.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        cycle.number = number
        cycle.startedAt = startedAt
        cycle.completedAt = isCompleted ? max(completedAt, startedAt) : nil
        cycle.wasRestarted = isCompleted ? wasRestarted : false
        try? context.save()
        dismiss()
    }

    private func delete() {
        let affectedExercises = cycle.sortedEntries.compactMap(\.exercise)
        context.delete(cycle)
        try? context.save()
        for exercise in affectedExercises {
            CycleEngine.syncFromLog(exercise: exercise, in: context)
        }
        dismiss()
    }
}
