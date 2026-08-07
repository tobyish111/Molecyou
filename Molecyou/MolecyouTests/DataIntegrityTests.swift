import Foundation
import SwiftUI
import Testing
@testable import Molecyou

/// Guards the scientific/data integrity of the knowledge graph so future edits can't silently
/// break accessions, citations, AlphaFold availability, or the JSON↔seed mirror.
@MainActor
struct DataIntegrityTests {
    private let bundled = KnowledgeGraphStore.loadBundled()
    private let seed = KnowledgeGraphStore(graph: SeedKnowledgeGraph.make())

    // MARK: Bundled JSON decodes and matches the in-code seed

    @Test func bundledGraphDecodesWithExpectedCardinality() {
        #expect(bundled.systems.count == 10)
        #expect(bundled.proteins.count == 34)
        #expect(bundled.pathways.count == 10)
        #expect(bundled.modules.count == 10)
        #expect(bundled.sources.count == 14)
    }

    @Test func bundledJSONAndSeedAreMirrorIdenticalOnIdentifiers() {
        #expect(Set(bundled.systems.map(\.id)) == Set(seed.systems.map(\.id)))
        #expect(Set(bundled.proteins.map(\.uniprotAccession)) == Set(seed.proteins.map(\.uniprotAccession)))
        #expect(Set(bundled.pathways.map(\.id)) == Set(seed.pathways.map(\.id)))
        #expect(Set(bundled.modules.map(\.id)) == Set(seed.modules.map(\.id)))
        #expect(Set(bundled.sources.map(\.id)) == Set(seed.sources.map(\.id)))
    }

    @Test func bundledJSONAndSeedAgreeOnProteinScience() {
        let bundledByAccession = Dictionary(uniqueKeysWithValues: bundled.proteins.map { ($0.uniprotAccession, $0) })
        for seedProtein in seed.proteins {
            let jsonProtein = bundledByAccession[seedProtein.uniprotAccession]
            #expect(jsonProtein?.geneSymbol == seedProtein.geneSymbol)
            #expect(jsonProtein?.alphaFoldAvailable == seedProtein.alphaFoldAvailable)
            #expect(jsonProtein?.sourceIDs == seedProtein.sourceIDs)
        }
    }

    // MARK: Referential integrity (runs against the shipping JSON)

    @Test func everyCrossReferenceResolves() {
        let systemIDs = Set(bundled.systems.map(\.id))
        let proteinIDs = Set(bundled.proteins.map(\.uniprotAccession))
        let pathwayIDs = Set(bundled.pathways.map(\.id))
        let moduleIDs = Set(bundled.modules.map(\.id))
        let sourceIDs = Set(bundled.sources.map(\.id))

        for system in bundled.systems {
            #expect(system.pathways.allSatisfy(pathwayIDs.contains))
            #expect(system.proteinAccessions.allSatisfy(proteinIDs.contains))
            #expect(system.moduleIDs.allSatisfy(moduleIDs.contains))
        }
        for pathway in bundled.pathways {
            #expect(systemIDs.contains(pathway.systemID))
            #expect(pathway.proteinAccessions.allSatisfy(proteinIDs.contains))
        }
        for protein in bundled.proteins {
            #expect(protein.systems.allSatisfy(systemIDs.contains))
            #expect(protein.sourceIDs.allSatisfy(sourceIDs.contains))
        }
        for module in bundled.modules {
            #expect(systemIDs.contains(module.systemID))
            #expect(module.sourceIDs.allSatisfy(sourceIDs.contains))
            for step in module.steps {
                #expect(!step.referenceIDs.isEmpty)
                #expect(step.referenceIDs.allSatisfy(sourceIDs.contains))
            }
        }
    }

    @Test func proteinSystemMembershipIsBidirectional() {
        let systemsByID = Dictionary(uniqueKeysWithValues: bundled.systems.map { ($0.id, $0) })
        for protein in bundled.proteins {
            for systemID in protein.systems {
                #expect(systemsByID[systemID]?.proteinAccessions.contains(protein.uniprotAccession) == true,
                        "\(protein.uniprotAccession) claims \(systemID) but is not listed there")
            }
        }
        for system in bundled.systems {
            for accession in system.proteinAccessions {
                #expect(bundled.protein(accession: accession)?.systems.contains(system.id) == true,
                        "\(system.id) lists \(accession) but the protein does not claim it")
            }
        }
    }

    @Test func noDuplicateAccessions() {
        let accessions = bundled.proteins.map(\.uniprotAccession)
        #expect(Set(accessions).count == accessions.count)
    }

    // MARK: AlphaFold availability

    @Test func onlyTitinLacksAnAlphaFoldStructure() {
        let unavailable = bundled.proteins.filter { !$0.alphaFoldAvailable }
        #expect(unavailable.map(\.uniprotAccession) == ["Q8WZ42"])
    }

    @Test func alphaFoldFlagAgreesWithSources() {
        for protein in bundled.proteins {
            #expect(protein.sourceIDs.contains("uniprot"))
            if protein.alphaFoldAvailable {
                #expect(protein.sourceIDs.contains("alphafold"))
            } else {
                #expect(!protein.sourceIDs.contains("alphafold"))
            }
        }
    }

    // MARK: Scientific spot-checks (lock verified accession↔gene mappings)

    @Test func verifiedAccessionsMapToCorrectGenes() {
        let expected: [String: String] = [
            "P69905": "HBA1", "P68871": "HBB", "P02144": "MB", "P02787": "TF",
            "P00915": "CA1", "P12883": "MYH7", "P16615": "ATP2A2", "Q8WZ42": "TTN",
            "O15516": "CLOCK", "O00327": "BMAL1", "P14672": "SLC2A4", "P06213": "INSR",
            "P01857": "IGHG1", "P01375": "TNF", "P01584": "IL1B", "P35367": "HRH1",
            "P41181": "AQP2", "P29972": "AQP1"
        ]
        for (accession, gene) in expected {
            #expect(bundled.protein(accession: accession)?.geneSymbol == gene, "\(accession) should be \(gene)")
        }
        #expect(bundled.proteins.allSatisfy { $0.organism == "Homo sapiens" })
    }

    @Test func statPearlsReferencesAreNamedAndLinked() {
        let references = bundled.sources.filter { $0.id.hasPrefix("sp-") }
        #expect(references.count == 12)
        for reference in references {
            #expect(reference.authors?.isEmpty == false, "\(reference.id) needs named authors")
            #expect(reference.url?.absoluteString.contains("ncbi.nlm.nih.gov/books/") == true)
            #expect(reference.license == "CC BY-NC-ND 4.0")
        }
    }

    @Test func everySystemAccentColorParses() {
        for system in bundled.systems {
            let parsed = system.accentColors.compactMap(Color.init(hex:))
            #expect(parsed.count == system.accentColors.count, "\(system.id) has an unparseable accent color")
        }
    }

    @Test func everyModuleTitleAndStepsAreWellFormed() {
        #expect(bundled.modules.allSatisfy { $0.title.hasPrefix("How ") })
        #expect(bundled.modules.allSatisfy { $0.steps.count >= 3 })
    }
}
