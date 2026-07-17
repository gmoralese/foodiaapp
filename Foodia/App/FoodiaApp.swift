import SwiftData
import SwiftUI

@main
struct FoodiaApp: App {
    private let container: ModelContainer = {
        do {
            let container = try ModelContainer(for: MealEntry.self, WaterEntry.self)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-seedDemo") {
                DemoSeeder.seed(container)
            }
            #endif
            return container
        } catch {
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
