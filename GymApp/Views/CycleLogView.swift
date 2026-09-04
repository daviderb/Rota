import SwiftUI
import SwiftData

/// History of one program's cycles, newest first. Each cycle header carries a
/// menu (edit number/dates, delete the whole cycle — including empty ones).
/// Entries are tappable to edit and swipe-deletable. The share button exports
/// the log as plain text, oldest cycle first.
struct CycleLogView: View {
    @Environment(\.modelContext) private var context
    let program: Program

    @Query private var allCycles: [CycleRecord]
    @Query private var categories: [WorkoutCategory]

    @State private var editingEntry: WorkoutLogEntry?
    @State private var editingCycle: CycleRecord?

    private var cycles: [CycleRecord] {
        allCycles
            .filter { !$0.isDeleted && $0.program?.persistentModelID == program.persistentModelID }
            .sorted { $0.number > $1.number }
    }

    var body: some View {
        List {
            if cycles.isEmpty {
                ContentUnavailableView(
                    "No Cycles Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Your \(program.name) history will appear here once you log exercises.")
                )
            }
            ForEach(cycles) { cycle in
                Section {
                    ForEach(cycle.sortedEntries) { entry in
                        Button {
                            editingEntry = entry
                        } label: {
                            LogEntryRow(entry: entry, color: color(for: entry))
                        }
                        // Keeps the row's own text colors instead of tinting
                        // the whole label with the accent color.
                        .buttonStyle(.plain)
                    }
                    .onDelete { deleteEntries(in: cycle, at: $0) }

                    if cycle.sortedEntries.isEmpty {
                        if cycle.completedAt == nil {
                            Text("No exercises logged yet")
                                .foregroundStyle(.secondary)
                        } else {
                            Button(role: .destructive) {
                                delete(cycle)
                            } label: {
                                Label("Delete this empty cycle", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Cycle \(cycle.number) · started \(cycle.startedAt.formatted(date: .abbreviated, time: .shortened))")
                        Spacer()
                        Menu {
                            Button("Edit Cycle…", systemImage: "pencil") { editingCycle = cycle }
                            Button("Delete Cycle \(cycle.number)", systemImage: "trash", role: .destructive) {
                                delete(cycle)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.body)
                        }
                    }
                } footer: {
                    Text(cycle.statusLabel)
                        .foregroundStyle(cycle.wasRestarted ? .orange : .secondary)
                }
            }
        }
        .navigationTitle("\(program.name) Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: exportText, preview: SharePreview("\(program.name) Cycle Log")) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(item: $editingEntry) { entry in
            LogEntryEditSheet(entry: entry)
        }
        .sheet(item: $editingCycle) { cycle in
            CycleEditSheet(cycle: cycle)
        }
    }

    /// Tile color of the matching current category; gray if renamed/deleted.
    private func color(for entry: WorkoutLogEntry) -> Color {
        categories.first {
            $0.name == entry.categoryName && $0.program?.persistentModelID == program.persistentModelID
        }?.color ?? .gray
    }

    private func deleteEntries(in cycle: CycleRecord, at offsets: IndexSet) {
        let entries = cycle.sortedEntries
        for index in offsets {
            let entry = entries[index]
            let exercise = entry.exercise
            context.delete(entry)
            if let exercise {
                CycleEngine.syncFromLog(exercise: exercise, in: context)
            }
        }
        try? context.save()
    }

    private func delete(_ cycle: CycleRecord) {
        let affectedExercises = cycle.sortedEntries.compactMap(\.exercise)
        context.delete(cycle)
        try? context.save()
        for exercise in affectedExercises {
            CycleEngine.syncFromLog(exercise: exercise, in: context)
        }
    }

    private var exportText: String {
        var lines: [String] = [
            "GymApp — \(program.name) Cycle Log",
            "Exported \(Date.now.formatted(date: .numeric, time: .shortened))",
            "",
        ]
        for cycle in cycles.sorted(by: { $0.number < $1.number }) {
            lines.append("Cycle \(cycle.number), started \(cycle.startedAt.formatted(date: .numeric, time: .shortened)):")
            lines.append("")
            if cycle.sortedEntries.isEmpty {
                lines.append("(no exercises logged)")
            }
            for entry in cycle.sortedEntries {
                lines.append("\(entry.categoryName): \(entry.exerciseName), \(entry.valueLabel), \(entry.performedAt.formatted(date: .numeric, time: .shortened))")
            }
            lines.append("")
            lines.append(cycle.statusLabel)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

struct LogEntryRow: View {
    let entry: WorkoutLogEntry
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.categoryName): \(entry.exerciseName)")
                    .foregroundStyle(.primary)
                Text(entry.performedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.valueLabel)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
