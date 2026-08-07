import Foundation
import Testing
@testable import Molecyou

/// Coverage for `KnowledgeGraphStore` lookups and search (the Explore feature's engine).
@MainActor
struct KnowledgeGraphTests {
    private let store = KnowledgeGraphStore(graph: SeedKnowledgeGraph.make())

    // MARK: Lookups

    @Test func lookupsResolveByID() {
        #expect(store.system(id: "oxygen-transport")?.name == "Oxygen Transport")
        #expect(store.system(id: "does-not-exist") == nil)
        #expect(store.protein(accession: "P69905")?.geneSymbol == "HBA1")
        #expect(store.protein(accession: "NOPE") == nil)
        #expect(store.module(id: "hemoglobin-function")?.systemID == "oxygen-transport")
        #expect(store.source(id: "uniprot")?.title == "UniProt Knowledgebase")
        #expect(store.source(id: "sp-bohr-effect")?.authors == "Benner A, Patel AK, Singh K, Dua A")
    }

    @Test func proteinsForSystemResolveThroughAccessions() {
        let system = store.system(id: "sleep-circadian")!
        let proteins = store.proteins(for: system)
        #expect(proteins.count == system.proteinAccessions.count)
        #expect(proteins.contains { $0.geneSymbol == "CLOCK" })
        #expect(proteins.contains { $0.geneSymbol == "BMAL1" })
    }

    @Test func modulesForSystemAndProteinsForModule() {
        let system = store.system(id: "cellular-energy")!
        #expect(store.modules(for: system).contains { $0.id == "cellular-atp" })
        let module = store.module(id: "cellular-atp")!
        #expect(!store.proteins(for: module).isEmpty)
    }

    @Test func sourcesAndReferencesResolve() {
        let module = store.module(id: "hemoglobin-function")!
        #expect(store.sources(for: module).map(\.id) == ["uniprot"])
        let step = module.steps.first { $0.id == "release" }!
        #expect(store.references(for: step).map(\.id) == ["sp-bohr-effect"])
        #expect(store.stepReferences(for: module).contains { $0.id == "sp-oxygen-transport" })
        #expect(store.stepReferences(for: module).contains { $0.id == "sp-bohr-effect" })
    }

    @Test func sourcesForProteinReflectAlphaFoldAvailability() {
        let hemoglobin = store.protein(accession: "P69905")!
        #expect(store.sources(for: hemoglobin).map(\.id).sorted() == ["alphafold", "uniprot"])
        let titin = store.protein(accession: "Q8WZ42")!
        #expect(store.sources(for: titin).map(\.id) == ["uniprot"])
    }

    // MARK: Search

    @Test func searchByGeneAccessionNameSystemPathwayModule() {
        #expect(store.search("HBB").contains { $0.title == "Hemoglobin subunit beta" })
        #expect(store.search("P68871").contains { $0.title == "Hemoglobin subunit beta" })
        #expect(store.search("hemoglobin").contains { $0.title.localizedCaseInsensitiveContains("Hemoglobin") })
        #expect(store.search("Oxygen Transport").contains { if case .system = $0 { return true } else { return false } })
        #expect(store.search("sliding filament").contains { if case .pathway = $0 { return true } else { return false } })
        #expect(store.search("How Hemoglobin").contains { if case .module = $0 { return true } else { return false } })
    }

    @Test func searchIsCaseInsensitiveAndTrimsWhitespace() {
        #expect(!store.search("  clock  ").isEmpty)
        #expect(!store.search("CLOCK").isEmpty)
        #expect(!store.search("clock").isEmpty)
    }

    @Test func searchWithNoMatchReturnsEmpty() {
        #expect(store.search("ZZZ_NOT_A_REAL_TERM").isEmpty)
    }

    @Test func emptyQueryReturnsEverything() {
        let all = store.search("")
        #expect(all.contains { if case .system = $0 { return true } else { return false } })
        #expect(all.contains { if case .protein = $0 { return true } else { return false } })
        #expect(all.contains { if case .module = $0 { return true } else { return false } })
        #expect(all.contains { if case .pathway = $0 { return true } else { return false } })
    }

    @Test func systemFilterRestrictsResults() {
        let filters = SearchFilters(systemID: "sleep-circadian")
        let results = store.search("", filters: filters)
        let proteinResults = results.compactMap { result -> Protein? in
            if case .protein(let protein) = result { return protein } else { return nil }
        }
        #expect(!proteinResults.isEmpty)
        #expect(proteinResults.allSatisfy { $0.systems.contains("sleep-circadian") })
    }

    @Test func molecularFunctionAndTypeFiltersRestrictProteins() {
        var filters = SearchFilters()
        filters.molecularFunction = "oxygen binding"
        let byFunction = store.search("", filters: filters).compactMap { result -> Protein? in
            if case .protein(let protein) = result { return protein } else { return nil }
        }
        #expect(!byFunction.isEmpty)
        #expect(byFunction.allSatisfy { $0.molecularFunction == "oxygen binding" })

        var typeFilters = SearchFilters()
        typeFilters.proteinType = "GPCR"
        let byType = store.search("", filters: typeFilters).compactMap { result -> Protein? in
            if case .protein(let protein) = result { return protein } else { return nil }
        }
        #expect(!byType.isEmpty)
        #expect(byType.allSatisfy { $0.proteinType == "GPCR" })
    }

    @Test func savedAndDownloadedFiltersUseProvidedSets() {
        var filters = SearchFilters()
        filters.savedOnly = true
        let saved = store.search("", filters: filters, savedAccessions: ["P69905"]).compactMap { result -> Protein? in
            if case .protein(let protein) = result { return protein } else { return nil }
        }
        #expect(saved.map(\.uniprotAccession) == ["P69905"])

        var downloadFilters = SearchFilters()
        downloadFilters.downloadedOnly = true
        let downloaded = store.search("", filters: downloadFilters, downloadedAccessions: ["P68871"]).compactMap { result -> Protein? in
            if case .protein(let protein) = result { return protein } else { return nil }
        }
        #expect(downloaded.map(\.uniprotAccession) == ["P68871"])
    }

    @Test func searchResultMetadataIsConsistent() {
        let result = store.search("P69905").first { if case .protein = $0 { return true } else { return false } }!
        #expect(result.id == "protein-P69905")
        #expect(result.title == "Hemoglobin subunit alpha")
        #expect(result.subtitle == "HBA1 · P69905")
        #expect(result.symbol == "atom")
    }
}
