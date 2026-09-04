import SwiftUI
import SwiftData
import Charts

/// One exercise: how it is tracked, plus its full log history and a progress
/// chart. Reached from Settings → program → category → exercise.
struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var exercise: Exercise

    @State private var editingEntry: WorkoutLogEntry?

    private var entries: [WorkoutLogEntry] {
        exercise.logEntries.filter { !$0.isDeleted }.sorted { $0.performedAt > $1.performedAt }
    }

    private var chartEntries: [WorkoutLogEntry] {
        exercise.logEntries
            .filter { !$0.isDeleted && $0.value != nil }
            .sorted { $0.performedAt < $1.performedAt }
    }

    var body: some View {
        List {
            Section {
                TextField("Name", text: $exercise.name)

                Picker("Track", selection: $exercise.tracking) {
                    ForEach(TrackingMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }

                if !exercise.tracking.units.isEmpty {
                    Picker("Unit", selection: $exercise.unitLabel) {
                        ForEach(exercise.tracking.units, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }

                    Stepper(
                        "Quick-adjust step: \(exercise.step.valueFormatted) \(exercise.unitLabel)",
                        value: $exercise.step,
                        in: stepRange,
                        step: stepGranularity
                    )
                }
            } header: {
                Text("Tracking")
            } footer: {
                Text(trackingFooter)
            }

            if chartEntries.count >= 2 {
                Section("Progress") {
                    Chart(chartEntries) { entry in
                        LineMark(
                            x: .value("Date", entry.performedAt),
                            y: .value(exercise.unitLabel, entry.value ?? 0)
                        )
                        .interpolationMethod(.monotone)
                        PointMark(
                            x: .value("Date", entry.performedAt),
                            y: .value(exercise.unitLabel, entry.value ?? 0)
                        )
                    }
                    .chartYScale(domain: chartDomain)
                    .frame(height: 180)
                    .padding(.vertical, 8)
                }
            }

            Section {
                if entries.isEmpty {
                    Text("No logs yet — history starts with your next workout.")
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    Button {
                        editingEntry = entry
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.performedAt.formatted(date: .abbreviated, time: .shortened))
                                Text("Cycle \(entry.cycle?.number ?? 0)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(entry.valueLabel)
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteEntries)
            } header: {
                Text("History")
            } footer: {
                if !entries.isEmpty {
                    Text("Tap an entry to edit it.")
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingEntry) { entry in
            LogEntryEditSheet(entry: entry)
        }
    }

    private var trackingFooter: String {
        switch exercise.tracking {
        case .untracked:
            "Tapping this exercise in a workout logs it immediately — no value to enter."
        case .weight:
            "You'll be asked for the weight each time, pre-filled with last time's."
        case .duration:
            "You'll be asked how long you held it, pre-filled with last time's."
        case .reps:
            "You'll be asked for the rep count, pre-filled with last time's."
        case .distance:
            "You'll be asked for the distance, pre-filled with last time's."
        }
    }

    /// Sensible bounds so the stepper can't reach absurd increments.
    private var stepRange: ClosedRange<Double> {
        switch exercise.tracking {
        case .duration where exercise.unitLabel == "s": 5...60
        case .duration: 1...15
        case .reps: 1...10
        case .distance where exercise.unitLabel == "m": 50...500
        case .distance: 0.25...5
        default: 0.5...20
        }
    }

    private var stepGranularity: Double {
        switch exercise.tracking {
        case .duration where exercise.unitLabel == "s": 5
        case .reps, .duration: 1
        case .distance where exercise.unitLabel == "m": 50
        case .distance: 0.25
        default: 0.5
        }
    }

    private var chartDomain: ClosedRange<Double> {
        let values = chartEntries.compactMap(\.value)
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        let padding = max((high - low) * 0.2, exercise.step * 2, 1)
        return max(0, low - padding)...(high + padding)
    }

    private func deleteEntries(at offsets: IndexSet) {
        let sorted = entries
        for index in offsets {
            context.delete(sorted[index])
        }
        try? context.save()
        CycleEngine.syncFromLog(exercise: exercise, in: context)
    }
}
