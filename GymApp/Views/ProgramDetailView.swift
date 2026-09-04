import SwiftUI
import SwiftData

/// Everything belonging to one program: its name and icon, its categories and
/// blueprint, its cycle log, and its restart action.
struct ProgramDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var program: Program

    @State private var showNewCategory = false
    @State private var confirmRestart = false

    var body: some View {
        Form {
            Section("Program") {
                TextField("Name", text: $program.name)
                IconPicker(selection: $program.iconName)
            }

            Section {
                ForEach(program.sortedCategories) { category in
                    NavigationLink {
                        CategoryDetailView(category: category)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(category.color)
                                .frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.name)
                                Text("\(category.exercises.count) exercise\(category.exercises.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("×\(category.blueprintCount)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteCategories)

                Button {
                    showNewCategory = true
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
            } header: {
                Text("Categories & Blueprint")
            } footer: {
                Text("×N is how many tiles of that category make up one cycle of \(program.name). Blueprint changes take effect when the current cycle completes — or restart it below.")
            }

            Section("History") {
                NavigationLink {
                    CycleLogView(program: program)
                } label: {
                    Label("Cycle Log", systemImage: "clock.arrow.circlepath")
                }
            }

            Section {
                NavigationLink {
                    ProgramExportView(program: program)
                } label: {
                    Label("Export / Share Program", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("Shares the setup only — categories, exercises and blueprint. No history or progress.")
            }

            Section {
                Button("Restart Cycle Now", role: .destructive) {
                    confirmRestart = true
                }
            }
        }
        .navigationTitle(program.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNewCategory) {
            NewCategorySheet(program: program)
        }
        .confirmationDialog("Restart this cycle?", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Restart Cycle", role: .destructive) {
                withAnimation {
                    CycleEngine.repopulate(for: program, in: context)
                }
            }
        } message: {
            Text("Remaining tiles of \(program.name) will be discarded and a fresh cycle created from the blueprint. Exercises already logged this cycle stay in the log — the cycle is marked as restarted.")
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        let categories = program.sortedCategories
        for index in offsets {
            context.delete(categories[index])
        }
        try? context.save()
    }
}
