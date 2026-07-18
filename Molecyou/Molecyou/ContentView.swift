import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SavedProtein.self, SavedSystem.self, SavedModule.self, UserNote.self, RecentView.self, CachedStructureRecord.self, UserPreferences.self], inMemory: true)
}
