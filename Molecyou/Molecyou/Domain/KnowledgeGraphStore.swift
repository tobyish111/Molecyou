import Foundation

@Observable
final class KnowledgeGraphStore {
    private let graph: KnowledgeGraph
    let systems: [BiologicalSystem]
    let pathways: [Pathway]
    let proteins: [Protein]
    let modules: [EducationModule]
    let sources: [SourceReference]

    // O(1) lookup indexes built once at init. Keys are unique by DataIntegrityTests
    // (no duplicate accessions / ids); `uniquingKeysWith` keeps the first to match the
    // previous `.first { }` semantics defensively.
    private let systemsByID: [String: BiologicalSystem]
    private let proteinsByAccession: [String: Protein]
    private let modulesByID: [String: EducationModule]
    private let sourcesByID: [String: SourceReference]

    // Search haystacks lowercased once at init so `search(_:)` doesn't re-lowercase every
    // field of every item on each keystroke. Fields are joined with "\n" so a substring
    // match can't span a field boundary (preserving the original per-field semantics).
    private let systemHaystacks: [(item: BiologicalSystem, text: String)]
    private let pathwayHaystacks: [(item: Pathway, text: String)]
    private let proteinHaystacks: [(item: Protein, text: String)]
    private let moduleHaystacks: [(item: EducationModule, text: String)]

    init(graph: KnowledgeGraph) {
        self.graph = graph
        self.systems = graph.systems
        self.pathways = graph.pathways
        self.proteins = graph.proteins
        self.modules = graph.modules
        self.sources = graph.sources
        self.systemsByID = Dictionary(graph.systems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.proteinsByAccession = Dictionary(graph.proteins.map { ($0.uniprotAccession, $0) }, uniquingKeysWith: { first, _ in first })
        self.modulesByID = Dictionary(graph.modules.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.sourcesByID = Dictionary(graph.sources.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.systemHaystacks = graph.systems.map { ($0, "\($0.name)\n\($0.shortDescription)".lowercased()) }
        self.pathwayHaystacks = graph.pathways.map { ($0, "\($0.name)\n\($0.summary)".lowercased()) }
        self.proteinHaystacks = graph.proteins.map { ($0, "\($0.name)\n\($0.geneSymbol)\n\($0.uniprotAccession)\n\($0.functionSummary)".lowercased()) }
        self.moduleHaystacks = graph.modules.map { ($0, "\($0.title)\n\($0.summary)".lowercased()) }
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
        systemsByID[id]
    }

    func protein(accession: String) -> Protein? {
        proteinsByAccession[accession]
    }

    func module(id: String) -> EducationModule? {
        modulesByID[id]
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

    func source(id: String) -> SourceReference? {
        sourcesByID[id]
    }

    func references(for step: EducationStep) -> [SourceReference] {
        step.referenceIDs.compactMap(source(id:))
    }

    /// The distinct named references cited across all of a module's steps.
    func stepReferences(for module: EducationModule) -> [SourceReference] {
        var seen = Set<String>()
        return module.steps
            .flatMap(\.referenceIDs)
            .filter { seen.insert($0).inserted }
            .compactMap(source(id:))
    }

    func search(_ query: String, filters: SearchFilters = SearchFilters(), savedAccessions: Set<String> = [], downloadedAccessions: Set<String> = []) -> [SearchResult] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var results: [SearchResult] = []

        for entry in systemHaystacks where filters.systemID == nil || filters.systemID == entry.item.id {
            if normalized.isEmpty || entry.text.contains(normalized) {
                results.append(.system(entry.item))
            }
        }

        for entry in pathwayHaystacks where filters.systemID == nil || filters.systemID == entry.item.systemID {
            if normalized.isEmpty || entry.text.contains(normalized) {
                results.append(.pathway(entry.item))
            }
        }

        for entry in proteinHaystacks {
            let protein = entry.item
            guard filters.systemID == nil || protein.systems.contains(filters.systemID ?? "") else { continue }
            guard filters.molecularFunction == nil || protein.molecularFunction == filters.molecularFunction else { continue }
            guard filters.proteinType == nil || protein.proteinType == filters.proteinType else { continue }
            guard !filters.savedOnly || savedAccessions.contains(protein.uniprotAccession) else { continue }
            guard !filters.downloadedOnly || downloadedAccessions.contains(protein.uniprotAccession) else { continue }

            if normalized.isEmpty || entry.text.contains(normalized) {
                results.append(.protein(protein))
            }
        }

        for entry in moduleHaystacks where filters.systemID == nil || filters.systemID == entry.item.systemID {
            if normalized.isEmpty || entry.text.contains(normalized) {
                results.append(.module(entry.item))
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
