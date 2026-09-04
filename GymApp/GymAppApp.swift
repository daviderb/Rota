import SwiftUI
import SwiftData

@main
struct GymAppApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Program.self, WorkoutCategory.self, Exercise.self,
                CycleTask.self, CycleRecord.self, WorkoutLogEntry.self
            )
        } catch {
            fatalError("Failed to set up SwiftData container: \(error)")
        }
        SeedData.seedIfNeeded(in: container.mainContext)
        SeedData.migrateToProgramsIfNeeded(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(container)
    }
}
