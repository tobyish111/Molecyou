import Foundation

@Observable
final class KnowledgeGraphStore {
    private let graph: KnowledgeGraph
    let systems: [BiologicalSystem]
    let pathways: [Pathway]
    let proteins: [Protein]
    let modules: [EducationModule]
    let sources: [SourceReference]

    init(graph: KnowledgeGraph) {
        self.graph = graph
        self.systems = graph.systems
        self.pathways = graph.pathways
        self.proteins = graph.proteins
        self.modules = graph.modules
        self.sources = graph.sources
    }

    static func loadBundled() -> KnowledgeGraphStore {
        guard let url = Bundle.main.url(forResource: "knowledge_graph", withExtension: "json") else {
            return .preview
        }

        do {
            let data = try Data(contentsOf: url)
            let graph = try JSONDecoder().decode(KnowledgeGraph.self, from: data)
            return KnowledgeGraphStore(graph: graph)
        } catch {
            return .preview
        }
    }

    static let preview = KnowledgeGraphStore(graph: SeedKnowledgeGraph.make())

    func system(id: String) -> BiologicalSystem? {
        systems.first { $0.id == id }
    }

    func protein(accession: String) -> Protein? {
        proteins.first { $0.uniprotAccession == accession }
    }

    func module(id: String) -> EducationModule? {
        modules.first { $0.id == id }
    }

    func proteins(for system: BiologicalSystem) -> [Protein] {
        system.proteinAccessions.compactMap(protein(accession:))
    }

    func proteins(for module: EducationModule) -> [Protein] {
        guard let system = system(id: module.systemID) else { return [] }
        return proteins(for: system)
    }

    func modules(for system: BiologicalSystem) -> [EducationModule] {
        system.moduleIDs.compactMap(module(id:))
    }

    func sources(for protein: Protein) -> [SourceReference] {
        protein.sourceIDs.compactMap { id in sources.first { $0.id == id } }
    }

    func sources(for module: EducationModule) -> [SourceReference] {
        module.sourceIDs.compactMap { id in sources.first { $0.id == id } }
    }

    func search(_ query: String, filters: SearchFilters = SearchFilters(), savedAccessions: Set<String> = [], downloadedAccessions: Set<String> = []) -> [SearchResult] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var results: [SearchResult] = []

        for system in systems where filters.systemID == nil || filters.systemID == system.id {
            if normalized.isEmpty || system.name.lowercased().contains(normalized) || system.shortDescription.lowercased().contains(normalized) {
                results.append(.system(system))
            }
        }

        for pathway in pathways where filters.systemID == nil || filters.systemID == pathway.systemID {
            if normalized.isEmpty || pathway.name.lowercased().contains(normalized) || pathway.summary.lowercased().contains(normalized) {
                results.append(.pathway(pathway))
            }
        }

        for protein in proteins {
            guard filters.systemID == nil || protein.systems.contains(filters.systemID ?? "") else { continue }
            guard filters.molecularFunction == nil || protein.molecularFunction == filters.molecularFunction else { continue }
            guard filters.proteinType == nil || protein.proteinType == filters.proteinType else { continue }
            guard !filters.savedOnly || savedAccessions.contains(protein.uniprotAccession) else { continue }
            guard !filters.downloadedOnly || downloadedAccessions.contains(protein.uniprotAccession) else { continue }

            if normalized.isEmpty || [protein.name, protein.geneSymbol, protein.uniprotAccession, protein.functionSummary].contains(where: { $0.lowercased().contains(normalized) }) {
                results.append(.protein(protein))
            }
        }

        for module in modules where filters.systemID == nil || filters.systemID == module.systemID {
            if normalized.isEmpty || module.title.lowercased().contains(normalized) || module.summary.lowercased().contains(normalized) {
                results.append(.module(module))
            }
        }

        return results
    }
}

enum SearchResult: Identifiable, Hashable, Sendable {
    case system(BiologicalSystem)
    case pathway(Pathway)
    case protein(Protein)
    case module(EducationModule)

    var id: String {
        switch self {
        case .system(let system): "system-\(system.id)"
        case .pathway(let pathway): "pathway-\(pathway.id)"
        case .protein(let protein): "protein-\(protein.uniprotAccession)"
        case .module(let module): "module-\(module.id)"
        }
    }

    var title: String {
        switch self {
        case .system(let system): system.name
        case .pathway(let pathway): pathway.name
        case .protein(let protein): protein.name
        case .module(let module): module.title
        }
    }

    var subtitle: String {
        switch self {
        case .system(let system): system.shortDescription
        case .pathway(let pathway): pathway.summary
        case .protein(let protein): "\(protein.geneSymbol) · \(protein.uniprotAccession)"
        case .module(let module): module.summary
        }
    }

    var symbol: String {
        switch self {
        case .system(let system): system.icon
        case .pathway: "point.3.connected.trianglepath.dotted"
        case .protein: "atom"
        case .module: "book.pages"
        }
    }
}
