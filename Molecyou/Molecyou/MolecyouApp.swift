import SwiftData
import SwiftUI

@main
struct MolecyouApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            // UI tests launch with the "UITesting" argument and use an in-memory store so each
            // test starts from a clean slate (saved proteins / notes don't leak across launches).
            // Production always uses the persistent on-disk store.
            let arguments = ProcessInfo.processInfo.arguments
            let isUITesting = arguments.contains("UITesting")
            let configuration = ModelConfiguration(isStoredInMemoryOnly: isUITesting)
            modelContainer = try ModelContainer(for: MolecularYouSchema.schema, configurations: configuration)

            // Seed onboarding state into the *writable* standard domain (rather than pinning it
            // via the read-only argument domain) for tests that flip onboarding at runtime —
            // "Reset app" (completed → onboarding) or the full onboarding flow (onboarding →
            // completed). Also gives a clean starting value immune to prior-run persistence.
            if isUITesting {
                if arguments.contains("UITestCompletedOnboarding") {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                } else if arguments.contains("UITestFreshOnboarding") {
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                }
            }
        } catch {
            fatalError("Unable to create Molecyou persistence container: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
        }
    }
}
