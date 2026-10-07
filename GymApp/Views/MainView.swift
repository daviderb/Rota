import SwiftUI
import SwiftData

/// The active cycle of the selected program: a grid of category tiles that
/// disappear as exercises are logged. When the last tile goes, that program's
/// cycle celebrates and repopulates — other programs are untouched.
struct MainView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Program.sortOrder) private var programs: [Program]
    @Query private var allTasks: [CycleTask]
    @Query private var allExercises: [Exercise]

    @AppStorage("selectedProgramName") private var selectedProgramName = ""
    @State private var selectedTask: CycleTask?
    @State private var pendingCompletion: (task: CycleTask, exercise: Exercise, weight: Double?)?
    @State private var showSettings = false
    @State private var showCelebration = false
    @State private var searchText = ""
    @State private var isSearchPresented = false
    /// The exercise picked from search, highlighted when its tile's picker opens.
    @State private var highlightedExercise: Exercise?

    private var isShowingSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchResults: [ExerciseSearchResult] {
        ExerciseSearch.results(for: searchText, exercises: allExercises, tasks: allTasks)
    }

    private var selectedProgram: Program? {
        programs.first { $0.name == selectedProgramName } ?? programs.first
    }

    private var tiles: [CycleTask] {
        guard let program = selectedProgram else { return [] }
        return allTasks
            .filter { !$0.isDeleted && $0.program?.persistentModelID == program.persistentModelID }
            .sorted {
                ($0.category?.sortOrder ?? .max, $0.createdAt) < ($1.category?.sortOrder ?? .max, $1.createdAt)
            }
    }

    /// One entry per category, however many reps of it the cycle still wants.
    private var tileGroups: [TileGroup] {
        var groups: [TileGroup] = []
        for task in tiles {
            let key = task.category?.persistentModelID
            if let index = groups.firstIndex(where: { $0.category?.persistentModelID == key }) {
                groups[index].tasks.append(task)
            } else {
                groups.append(TileGroup(category: task.category, tasks: [task]))
            }
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isShowingSearch {
                    ExerciseSearchResultsView(
                        query: searchText,
                        results: searchResults,
                        showsProgram: programs.count > 1,
                        onSelect: open
                    )
                } else if programs.isEmpty {
                    ContentUnavailableView {
                        Label("No Programs Yet", systemImage: "square.grid.2x2")
                    } description: {
                        Text("Create a program — like Workout or Stretching — to start a cycle.")
                    } actions: {
                        Button("Open Settings") { showSettings = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else if tiles.isEmpty && !showCelebration {
                    ContentUnavailableView {
                        Label("Nothing in This Cycle", systemImage: "tray")
                    } description: {
                        Text("Add categories to \(selectedProgram?.name ?? "this program") and set how many tiles each one contributes.")
                    } actions: {
                        Button("Open Settings") { showSettings = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                            ForEach(tileGroups) { group in
                                Button {
                                    selectedTask = group.next
                                } label: {
                                    CycleTileView(
                                        category: group.category,
                                        iconName: selectedProgram?.iconName ?? "dumbbell.fill",
                                        remaining: group.remaining
                                    )
                                }
                                .buttonStyle(PressableCardStyle())
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding()
                    }
                }

                if showCelebration {
                    CelebrationView()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .navigationTitle(selectedProgram?.name ?? "GymApp")
            // With the pill bar on screen the program name is already obvious,
            // so the large title would only add dead space.
            .navigationBarTitleDisplayMode(programs.count > 1 ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Find an exercise"
            )
            .safeAreaInset(edge: .top) {
                // Search spans every program, so the switcher steps aside.
                if programs.count > 1 && !isShowingSearch {
                    ProgramPillBar(programs: programs, selectedName: $selectedProgramName)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !tiles.isEmpty && !isShowingSearch {
                    Text("\(tiles.count) exercise\(tiles.count == 1 ? "" : "s") to go")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }
            }
            .sheet(item: $selectedTask, onDismiss: {
                highlightedExercise = nil
                processPendingCompletion()
            }) { task in
                ExercisePickerView(task: task, highlighted: highlightedExercise) { exercise, weight in
                    pendingCompletion = (task, exercise, weight)
                    selectedTask = nil
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSettings, onDismiss: ensureCycles) {
                SettingsView()
            }
            .task { ensureCycles() }
            .onChange(of: programs.count) { ensureCycles() }
        }
    }

    private func ensureCycles() {
        CycleEngine.repopulateAllIfEmpty(in: context)
    }

    /// Opens the tile a search result lives behind, switching to its program
    /// so the grid underneath matches once the search is dismissed.
    private func open(_ result: ExerciseSearchResult) {
        guard let task = result.nextTask else { return }
        if let programName = result.program?.name {
            selectedProgramName = programName
        }
        highlightedExercise = result.exercise
        selectedTask = task
    }

    /// Runs after the picker sheet is fully dismissed, so the model deletion
    /// never races the sheet's own rendering.
    private func processPendingCompletion() {
        guard let completion = pendingCompletion else { return }
        pendingCompletion = nil
        let program = completion.task.program ?? completion.task.category?.program

        // Back to the grid, where the tile that was just counted down is visible.
        searchText = ""
        isSearchPresented = false

        withAnimation(.spring(duration: 0.4)) {
            CycleEngine.complete(
                task: completion.task,
                exercise: completion.exercise,
                value: completion.weight,
                in: context
            )
        }

        guard let program, CycleEngine.remainingTaskCount(for: program, in: context) == 0 else { return }
        withAnimation(.spring(duration: 0.4)) {
            showCelebration = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.spring(duration: 0.5)) {
                showCelebration = false
                CycleEngine.repopulate(for: program, in: context)
            }
        }
    }
}

/// The outstanding reps of one category, drawn as a single counting tile.
struct TileGroup: Identifiable {
    let category: WorkoutCategory?
    var tasks: [CycleTask]

    /// Stable across completions so the tile animates its count rather than
    /// being torn down and rebuilt.
    var id: String {
        category.map { "\($0.persistentModelID)" } ?? "uncategorised"
    }

    var remaining: Int { tasks.count }
    var next: CycleTask? { tasks.first }
}

/// Horizontal switcher shown when more than one program exists.
struct ProgramPillBar: View {
    let programs: [Program]
    @Binding var selectedName: String

    private var resolvedName: String {
        programs.contains { $0.name == selectedName } ? selectedName : (programs.first?.name ?? "")
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(programs) { program in
                    let isSelected = program.name == resolvedName
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            selectedName = program.name
                        }
                    } label: {
                        Label(program.name, systemImage: program.iconName)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .background(.bar)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Program.self, WorkoutCategory.self, Exercise.self,
        CycleTask.self, CycleRecord.self, WorkoutLogEntry.self,
        configurations: config
    )
    SeedData.seedIfNeeded(in: container.mainContext, force: true)
    CycleEngine.repopulateAllIfEmpty(in: container.mainContext)
    return MainView().modelContainer(container)
}
