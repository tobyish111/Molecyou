import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("demonstrationMode") private var demonstrationMode = true
    @State private var environment: AppEnvironment?

    var body: some View {
        Group {
            if let environment {
                if hasCompletedOnboarding {
                    MainTabView(environment: environment)
                } else {
                    OnboardingView(environment: environment, hasCompletedOnboarding: $hasCompletedOnboarding)
                }
            } else {
                ProgressView("Preparing Molecyou")
            }
        }
        .task {
            if environment == nil {
                environment = AppEnvironment.live(modelContext: modelContext, demonstrationMode: demonstrationMode)
            }
        }
        .onChange(of: demonstrationMode) { _, newValue in
            environment = AppEnvironment.live(modelContext: modelContext, demonstrationMode: newValue)
        }
    }
}

struct MainTabView: View {
    @Bindable var environment: AppEnvironment
    @State private var todayPath: [AppRoute] = []
    @State private var explorePath: [AppRoute] = []
    @State private var libraryPath: [AppRoute] = []

    var body: some View {
        TabView {
            NavigationStack(path: $todayPath) {
                TodayView(environment: environment)
                    .navigationDestination(for: AppRoute.self) { destinationView($0) }
            }
            .tabItem { Label("Today", systemImage: "sparkles") }

            NavigationStack(path: $explorePath) {
                ExploreView(environment: environment)
                    .navigationDestination(for: AppRoute.self) { destinationView($0) }
            }
            .tabItem { Label("Explore", systemImage: "magnifyingglass") }

            NavigationStack(path: $libraryPath) {
                LibraryView(environment: environment)
                    .navigationDestination(for: AppRoute.self) { destinationView($0) }
            }
            .tabItem { Label("Library", systemImage: "books.vertical") }
        }
        .tint(.myAccent)
    }

    @ViewBuilder
    private func destinationView(_ route: AppRoute) -> some View {
        switch route {
        case .system(let id):
            if let system = environment.knowledgeGraph.system(id: id) {
                SystemDetailView(environment: environment, system: system)
            } else {
                ErrorStateView(title: "System unavailable", message: "The selected system is not in the local knowledge graph.", actionTitle: nil, action: nil)
            }
        case .protein(let accession):
            if let protein = environment.knowledgeGraph.protein(accession: accession) {
                ProteinDetailView(environment: environment, protein: protein)
            } else {
                ErrorStateView(title: "Protein unavailable", message: "The selected protein could not be found in bundled content.", actionTitle: nil, action: nil)
            }
        case .functionModule(let id):
            if let module = environment.knowledgeGraph.module(id: id) {
                FunctionExplanationView(environment: environment, module: module)
            } else {
                ErrorStateView(title: "Module unavailable", message: "This lesson is not available.", actionTitle: nil, action: nil)
            }
        case .viewer(let accession):
            if let protein = environment.knowledgeGraph.protein(accession: accession) {
                MolecularViewerScreen(environment: environment, protein: protein)
            }
        case .healthContext(let id):
            if let system = environment.knowledgeGraph.system(id: id) {
                HealthContextView(environment: environment, system: system)
            }
        }
    }
}

struct ErrorStateView: View {
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: MYSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(MYSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .moleculeScreenBackground()
    }
}
