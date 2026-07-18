import SwiftData
import SwiftUI

@main
struct MolecyouApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: MolecularYouSchema.schema)
        } catch {
            fatalError("Unable to create Molecular You persistence container: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
        }
    }
}
