import SwiftUI

/// Quick value input for the selected exercise, adapted to how that exercise
/// is tracked (weight, time, reps or distance). Pre-filled with last time's
/// value; the −/+ buttons step by the exercise's configured increment.
struct LogValueView: View {
    let exercise: Exercise
    let onLog: (Double?) -> Void

    @State private var valueText: String
    @FocusState private var fieldFocused: Bool

    init(exercise: Exercise, onLog: @escaping (Double?) -> Void) {
        self.exercise = exercise
        self.onLog = onLog
        _valueText = State(initialValue: exercise.lastValue?.editingString ?? "")
    }

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text(exercise.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(previousLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            HStack(spacing: 20) {
                adjustButton("minus.circle.fill", by: -exercise.step)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0", text: $valueText)
                        .keyboardType(.decimalPad)
                        .focused($fieldFocused)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 140)
                    Text(exercise.unitLabel)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                adjustButton("plus.circle.fill", by: exercise.step)
            }

            Button {
                onLog(parsedValue)
            } label: {
                Text("Log & Complete")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)

            Spacer()
        }
        .navigationTitle("Log \(exercise.tracking.label)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { fieldFocused = true }
    }

    private var previousLabel: String {
        if let last = exercise.lastValue {
            return "Last time: \(last.valueFormatted) \(exercise.unitLabel)"
        }
        return "First log — enter your starting value"
    }

    private var parsedValue: Double? {
        // Accept both "62.5" and the German keyboard's "62,5".
        Double(valueText.replacingOccurrences(of: ",", with: "."))
    }

    private func adjustButton(_ symbol: String, by delta: Double) -> some View {
        Button {
            let current = parsedValue ?? exercise.lastValue ?? 0
            valueText = max(0, current + delta).editingString
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 34))
                .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
        .disabled(delta == 0)
    }
}
