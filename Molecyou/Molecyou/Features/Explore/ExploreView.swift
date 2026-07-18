import SwiftUI

struct ExploreView: View {
    let environment: AppEnvironment
    @State private var query = ""
    @State private var selectedSystemID: String?
    @State private var savedOnly = false
    @State private var downloadedOnly = false

    private var filters: SearchFilters {
        SearchFilters(systemID: selectedSystemID, savedOnly: savedOnly, downloadedOnly: downloadedOnly)
    }

    private var results: [SearchResult] {
        environment.knowledgeGraph.search(query, filters: filters, savedAccessions: environment.libraryRepository.savedProteinAccessions, downloadedAccessions: environment.libraryRepository.downloadedProteinAccessions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MYSpacing.lg) {
                filterBar
                if query.isEmpty && selectedSystemID == nil && !savedOnly && !downloadedOnly {
                    featured
                    trending
                    browseFunctions
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
        .onAppear { environment.libraryRepository.refresh() }
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
                    Label(selectedSystemID.flatMap { environment.knowledgeGraph.system(id: $0)?.name } ?? "System", systemImage: "line.3.horizontal.decrease.circle")
                }
                Toggle("Saved", isOn: $savedOnly).toggleStyle(.button)
                Toggle("Downloaded", isOn: $downloadedOnly).toggleStyle(.button)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var featured: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Featured Systems")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(environment.knowledgeGraph.systems.prefix(5)) { system in
                    NavigationLink(value: AppRoute.system(system.id)) {
                        FeaturedSystemCard(system: system)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var trending: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Trending Educational Topics")
            ForEach(environment.knowledgeGraph.modules.prefix(4)) { module in
                NavigationLink(value: AppRoute.functionModule(module.id)) {
                    SearchRow(symbol: "book.pages", title: module.title, subtitle: module.summary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var browseFunctions: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            SectionTitle(title: "Browse by Biological Function")
            let functions = Array(Set(environment.knowledgeGraph.proteins.map(\.molecularFunction))).sorted().prefix(8)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(Array(functions), id: \.self) { item in
                    Text(item.capitalized)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.myPanel, in: RoundedRectangle(cornerRadius: MYRadius.md))
                }
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
}

struct FeaturedSystemCard: View {
    let system: BiologicalSystem

    var body: some View {
        VStack(alignment: .leading, spacing: MYSpacing.md) {
            GradientIcon(symbol: system.icon, colors: system.accentColors.compactMap(Color.init(hex:)))
            Text(system.name).font(.headline)
            Text(system.shortDescription).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MYSpacing.md)
        .background(Color.myPanel, in: RoundedRectangle(cornerRadius: MYRadius.lg, style: .continuous))
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
