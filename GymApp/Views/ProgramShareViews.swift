import SwiftUI
import SwiftData
import UIKit

/// Shows a program's shareable blueprint and offers to copy or share it.
struct ProgramExportView: View {
    let program: Program

    @State private var didCopy = false

    private var text: String { ProgramBlueprint(program: program).encoded() }

    var body: some View {
        List {
            Section {
                Button {
                    UIPasteboard.general.string = text
                    withAnimation { didCopy = true }
                } label: {
                    Label(didCopy ? "Copied!" : "Copy to Clipboard",
                          systemImage: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                }
                ShareLink(item: text, preview: SharePreview("\(program.name) — GymApp program")) {
                    Label("Share…", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("Contains the program name, its categories with colors and tiles per cycle, and every exercise with how it's tracked. Your logs, weights and current progress are **not** included.")
            }

            Section("Preview") {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Export \(program.name)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Paste a shared program to add it alongside your own.
struct ProgramImportSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""

    private var parsed: Result<ProgramBlueprint, Error>? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        do { return .success(try ProgramBlueprint.decoded(from: text)) }
        catch { return .failure(error) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PasteButton(payloadType: String.self) { strings in
                        if let pasted = strings.first { text = pasted }
                    }
                    .labelStyle(.titleAndIcon)
                } footer: {
                    Text("Paste a program someone shared with you, or type it in below.")
                }

                Section("Program text") {
                    TextEditor(text: $text)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 160)
                }

                switch parsed {
                case .success(let blueprint):
                    Section("Will import") {
                        LabeledContent("Name", value: blueprint.name)
                        LabeledContent("Categories", value: "\(blueprint.categories.count)")
                        LabeledContent("Exercises", value: "\(blueprint.exerciseCount)")
                        LabeledContent("Tiles per cycle", value: "\(blueprint.tilesPerCycle)")
                    }
                case .failure(let error):
                    Section {
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                case nil:
                    EmptyView()
                }
            }
            .navigationTitle("Import Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        if case .success(let blueprint) = parsed {
                            blueprint.makeProgram(in: context)
                            dismiss()
                        }
                    }
                    .disabled(isImportDisabled)
                }
            }
        }
    }

    private var isImportDisabled: Bool {
        if case .success = parsed { return false }
        return true
    }
}
