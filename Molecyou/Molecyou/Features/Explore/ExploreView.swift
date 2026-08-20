import SwiftUI

struct ExploreView: View {
    let environment: AppEnvironment
    @State private var query = ""
    @State private var selectedSystemID: String?
    @State private var savedOnly = false
    @State private var downloadedOnly = false
    @State private var healthSnapshot = HealthSnapshot.empty(isDemo: true)
    @State private var healthRecommendations: [HealthContextRecommendation] = []
    @State private var results: [SearchResult] = []

    private var filters: SearchFilters {
        SearchFilters(systemID: selectedSystemID, savedOnly: savedOnly, downloadedOnly: downloadedOnly)
    }

    /// Everything `search(_:)` depends on. Recompute results only when this changes,
    /// instead of re-running the search on every unrelated body re-render.
    private var searchKey: SearchInputsKey {
        SearchInputsKey(
            query: query,
            systemID: selectedSystemID,
            savedOnly: savedOnly,
            downloadedOnly: downloadedOnly,
            saved: environment.libraryRepository.savedProteinAccessions,
            downloaded: environment.libraryRepository.downloadedProteinAccessions
        )
    }

    private var activityModules: [EducationModule] {
        let recommendedModules = healthRecommendations.flatMap { recommendation -> [EducationModule] in
            guard let system = environment.knowledgeGraph.system(id: recommendation.systemID) else { return [] }
            return environment.knowledgeGraph.modules(for: system)
        }
        let fallbackModules = recommendedModules.isEmpty ? Array(environment.knowledgeGraph.modules.prefix(4)) : recommendedModules
        var seenModuleIDs = Set<String>()
        return fallbackModules.filter { seenModuleIDs.insert($0.id).inserted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MYSpacing.lg) {
                filterBar
                if query.isEmpty && selectedSystemID == nil && !savedOnly && !downloadedOnly {
                    systemsSection
                    activityBasedModules
                } else if results.isEmpty {
                    ErrorStateView(title: "No results", message: "Try a different protein, system, pathway, or filter.", actionTitle: "Clear filters") { clearFilters() }
                        .frame(minHeight: 360)
                } else {
                    resultsList
                }
            }
            .padding(MYSpacing.md)
        }
        .navigationTitle("Explore")
        .searchable(text: $query, prompt: "Search proteins and systems")
        .moleculeScreenBackground()
        .onAppear {
            environment.libraryRepository.refresh()
            recomputeResults()
        }
        .onChange(of: searchKey) { _, _ in recomputeResults() }
        // Reload activity recommendations when health data is invalidated (access granted /
        // returned to foreground), in addition to first appearance.
        .task(id: environment.healthRefreshID) { await loadActivityRecommendations() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Menu {
                    Button("All Systems") { selectedSystemID = nil }
                    ForEach(environment.knowledgeGraph.systems) { system in
                        Button(system.name) { selectedSystemID = system.id }
                    }
                } label: {
                    Label {
                        Text(selectedSystemID.flatMap { environment.knowledgeGraph.system(id: $0)?.name } ?? "System")
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: 118, alignment: .leading)
                    } icon: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                Toggle("Saved", isOn: $savedOnly).toggleStyle(.button)
                Toggle("Downloaded", isOn: $downloadedOnly).toggleStyle(.button)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var systemsSection: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Systems", detail: "Tap a system to open it")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(environment.knowledgeGraph.systems) { system in
                    NavigationLink(value: AppRoute.system(system.id)) {
                        FeaturedSystemCard(system: system)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var activityBasedModules: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Based on Your Activity", detail: healthSnapshot.isDemo ? "Demo data" : nil)
            ForEach(activityModules) { module in
                NavigationLink(value: AppRoute.functionModule(module.id)) {
                    ActivityModuleRow(
                        module: module,
                        system: environment.knowledgeGraph.system(id: module.systemID),
                        evidence: healthSnapshot.matchingEvidence(for: module.systemID).first
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Results", detail: "\(results.count)")
            ForEach(results) { result in
                NavigationLink(value: route(for: result)) {
                    SearchRow(symbol: result.symbol, title: result.title, subtitle: result.subtitle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func route(for result: SearchResult) -> AppRoute {
        switch result {
        case .system(let system): .system(system.id)
        case .pathway(let pathway): .system(pathway.systemID)
        case .protein(let protein): .protein(protein.uniprotAccession)
        case .module(let module): .functionModule(module.id)
        }
    }

    private func clearFilters() {
        query = ""
        selectedSystemID = nil
        savedOnly = false
        downloadedOnly = false
    }

    private func recomputeResults() {
        results = environment.knowledgeGraph.search(
            query,
            filters: filters,
            savedAccessions: environment.libraryRepository.savedProteinAccessions,
            downloadedAccessions: environment.libraryRepository.downloadedProteinAccessions
        )
    }

    private func loadActivityRecommendations() async {
        let snapshot = await environment.healthProvider.snapshot()
        healthSnapshot = snapshot
        healthRecommendations = environment.contextEngine.evaluate(snapshot: snapshot, interests: Set(UserInterest.allCases))
    }
}

/// Value-equatable snapshot of every input to `KnowledgeGraphStore.search`, used to drive
/// `onChange` so results recompute only when a relevant input actually changes.
private struct SearchInputsKey: Equatable {
    let query: String
    let systemID: String?
    let savedOnly: Bool
    let downloadedOnly: Bool
    let saved: Set<String>
    let downloaded: Set<String>
}

struct FeaturedSystemCard: View {
    let system: BiologicalSystem
    var isHighlighted = false

    private var colors: [Color] {
        let systemColors = system.accentColors.compactMap(Color.init(hex:))
        return systemColors.isEmpty ? [Color.myAccent, .cyan] : systemColors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            HStack(alignment: .top) {
                GradientIcon(symbol: system.icon, colors: colors)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
            Text(system.name).font(.headline)
            Text(system.shortDescription).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
        .padding(MYSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous)
                .fill(Color.myPanel)
                .overlay(alignment: .topLeading) {
                    LinearGradient(colors: colors.map { $0.opacity(0.18) } + [.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous)
                        .stroke(isHighlighted ? (colors.first ?? Color.myAccent) : Color.primary.opacity(0.08), lineWidth: isHighlighted ? 2 : 1)
                }
        }
        .shadow(color: (isHighlighted ? (colors.first ?? Color.myAccent) : .black).opacity(isHighlighted ? 0.18 : 0.05), radius: isHighlighted ? 18 : 8, x: 0, y: isHighlighted ? 10 : 4)
    }
}

struct ActivityModuleRow: View {
    let module: EducationModule
    let system: BiologicalSystem?
    let evidence: HealthContextEvidence?

    private var colors: [Color] {
        let systemColors = system?.accentColors.compactMap(Color.init(hex:)) ?? []
        return systemColors.isEmpty ? [Color.myAccent, .cyan] : systemColors
    }

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: MYSpacing.md) {
                GradientIcon(symbol: system?.icon ?? "book.pages", colors: colors)
                VStack(alignment: .leading, spacing: MYSpacing.xs) {
                    Text(module.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(evidence?.detail ?? module.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    Label(system?.name ?? "How it works", systemImage: evidence?.symbol ?? "book.pages")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(colors.first ?? Color.myAccent)
                        .padding(.top, 2)
                }
                Spacer(minLength: MYSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .background {
            LinearGradient(
                colors: colors.map { $0.opacity(0.10) } + [Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
        }
    }
}

struct SearchRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        GlassCard {
            HStack(spacing: MYSpacing.md) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.myAccent)
                    .frame(width: 38, height: 38)
                    .background(Color.myAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: MYRadius.sm))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Explore") {
    NavigationStack { ExploreView(environment: .preview) }
}
