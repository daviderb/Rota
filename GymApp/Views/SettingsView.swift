import SwiftUI
import SwiftData

/// Top level of settings: the list of programs. Everything else (categories,
/// blueprint, exercises, log) lives inside a program.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Program.sortOrder) private var programs: [Program]

    @State private var showNewProgram = false
    @State private var showImportProgram = false
    @State private var programPendingDeletion: Program?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(programs) { program in
                        NavigationLink {
                            ProgramDetailView(program: program)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: program.iconName)
                                    .font(.title3)
                                    .foregroundStyle(.tint)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(program.name)
                                    Text("\(program.categories.count) categor\(program.categories.count == 1 ? "y" : "ies") · \(program.tilesPerCycle) tile\(program.tilesPerCycle == 1 ? "" : "s") per cycle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: requestDelete)
                    .onMove(perform: move)

                    Button {
                        showNewProgram = true
                    } label: {
                        Label("Add Program", systemImage: "plus")
                    }

                    Button {
                        showImportProgram = true
                    } label: {
                        Label("Import Program", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Programs")
                } footer: {
                    Text("Each program runs its own independent cycle — a Stretching exercise never fills a Workout tile. Tap one to manage its categories, blueprint and log.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showNewProgram) {
                NewProgramSheet()
            }
            .sheet(isPresented: $showImportProgram) {
                ProgramImportSheet()
            }
            .confirmationDialog(
                "Delete “\(programPendingDeletion?.name ?? "")”?",
                isPresented: $showDeleteConfirmation,
                presenting: programPendingDeletion
            ) { program in
                Button("Delete Program", role: .destructive) { delete(program) }
            } message: { _ in
                Text("This also deletes its categories, exercises and entire cycle log. This cannot be undone.")
            }
        }
    }

    private func requestDelete(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        programPendingDeletion = programs[index]
        showDeleteConfirmation = true
    }

    private func delete(_ program: Program) {
        context.delete(program)
        try? context.save()
        programPendingDeletion = nil
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = programs
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, program) in reordered.enumerated() {
            program.sortOrder = index
        }
        try? context.save()
    }
}

/// Small form for creating a program.
struct NewProgramSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var programs: [Program]

    @State private var name = ""
    @State private var iconName = ProgramIcon.symbols[0]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. Stretching)", text: $name)
                IconPicker(selection: $iconName)
            }
            .navigationTitle("New Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let maxOrder = programs.map(\.sortOrder).max() ?? -1
                        context.insert(
                            Program(
                                name: name.trimmingCharacters(in: .whitespaces),
                                iconName: iconName,
                                sortOrder: maxOrder + 1
                            )
                        )
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct IconPicker: View {
    @Binding var selection: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 10) {
            ForEach(ProgramIcon.symbols, id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(symbol == selection ? Color.accentColor : Color.secondary.opacity(0.15))
                    )
                    .foregroundStyle(symbol == selection ? .white : .primary)
                    .onTapGesture { selection = symbol }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Small form for creating a category inside a program.
struct NewCategorySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let program: Program

    @State private var name = ""
    @State private var colorHex = Palette.hexes[0]
    @State private var blueprintCount = 2

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. Hamstrings)", text: $name)
                ColorPalettePicker(selection: $colorHex)
                TileCountField(count: $blueprintCount)
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let maxOrder = program.categories.map(\.sortOrder).max() ?? -1
                        context.insert(
                            WorkoutCategory(
                                name: name.trimmingCharacters(in: .whitespaces),
                                colorHex: colorHex,
                                blueprintCount: blueprintCount,
                                sortOrder: maxOrder + 1,
                                program: program
                            )
                        )
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Tiles-per-cycle input: type any number, or step it. No small upper bound —
/// a category can appear as many times per cycle as you like.
struct TileCountField: View {
    @Binding var count: Int

    var body: some View {
        HStack {
            Text("Tiles per cycle")
            Spacer()
            TextField("0", value: $count, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
            Stepper("Tiles per cycle", value: $count, in: 0...999)
                .labelsHidden()
        }
        .onChange(of: count) { _, newValue in
            let clamped = max(0, min(newValue, 999))
            if clamped != newValue { count = clamped }
        }
    }
}

struct ColorPalettePicker: View {
    @Binding var selection: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 10) {
            ForEach(Palette.hexes, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 34, height: 34)
                    .overlay {
                        if hex == selection {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { selection = hex }
            }
        }
        .padding(.vertical, 4)
    }
}
