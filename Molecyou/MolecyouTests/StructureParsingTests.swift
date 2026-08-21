import Foundation
import SceneKit
import Testing
@testable import Molecyou

/// Coverage for mmCIF parsing, structure-part segmentation, the structure cache, and the viewer model.
struct StructureParsingTests {
    // MARK: MMCIFAtomParser

    @Test func parsesValidAtomsWithFields() throws {
        let atoms = try MMCIFAtomParser.parse(TestFixtures.sampleMMCIF(residueCount: 5))
        #expect(atoms.count == 5)
        let first = atoms[0]
        #expect(first.atomName == "CA")
        #expect(first.element == "C")
        #expect(first.chainID == "A")
        #expect(first.sequenceNumber == 1)
        #expect(first.confidence == 95)
        #expect(first.position.x == 0)
    }

    @Test func allowsHetatmAndSkipsMissingCoordinates() throws {
        let text = """
        data_test
        #
        loop_
        _atom_site.group_PDB
        _atom_site.type_symbol
        _atom_site.label_atom_id
        _atom_site.label_asym_id
        _atom_site.label_seq_id
        _atom_site.Cartn_x
        _atom_site.Cartn_y
        _atom_site.Cartn_z
        ATOM C CA A 1 1.0 2.0 3.0
        HETATM FE FE A 2 4.0 5.0 6.0
        ATOM C CB A . 7.0 8.0 9.0
        ATOM C CG A 4 . 8.0 9.0
        #
        """
        let atoms = try MMCIFAtomParser.parse(text)
        // Three rows have valid coordinates (the one with x=="." is skipped).
        #expect(atoms.count == 3)
        #expect(atoms.contains { $0.element == "FE" })
        // The row with seq_id "." parses but has a nil sequence number.
        #expect(atoms.contains { $0.sequenceNumber == nil })
    }

    @Test func handlesQuotedTokens() throws {
        let text = """
        data_test
        #
        loop_
        _atom_site.group_PDB
        _atom_site.type_symbol
        _atom_site.label_atom_id
        _atom_site.label_asym_id
        _atom_site.label_seq_id
        _atom_site.Cartn_x
        _atom_site.Cartn_y
        _atom_site.Cartn_z
        ATOM C 'CA' A 1 1.0 2.0 3.0
        #
        """
        let atoms = try MMCIFAtomParser.parse(text)
        #expect(atoms.count == 1)
        #expect(atoms[0].atomName == "CA")
    }

    @Test func throwsWhenNoAtoms() {
        #expect(throws: MMCIFAtomParser.ParserError.self) {
            _ = try MMCIFAtomParser.parse("data_empty\n#\n")
        }
    }

    // MARK: ProteinStructurePart

    @Test func segmentsFortyResiduesIntoFourParts() {
        let parts = ProteinStructurePart.make(from: TestFixtures.sampleMMCIF(residueCount: 40))
        #expect(parts.count == 4)
        let first = parts[0]
        #expect(first.chainID == "A")
        #expect(first.subtitle == "Residues 1-10")
        #expect(first.residueCount == 10)
        #expect(first.focusSequenceNumber == 5)
        #expect(first.id == "A-1-10")
    }

    @Test func singleResidueProducesOnePart() {
        let parts = ProteinStructurePart.make(from: TestFixtures.sampleMMCIF(residueCount: 1))
        #expect(parts.count == 1)
        #expect(parts[0].subtitle == "Residue 1")
        #expect(parts[0].residueCount == 1)
    }

    @Test func invalidStructureYieldsNoParts() {
        #expect(ProteinStructurePart.make(from: "not a structure").isEmpty)
    }

    @Test func multipleChainsAreSortedAndSegmented() {
        let chainA = TestFixtures.sampleMMCIF(residueCount: 10, chain: "A")
        let chainB = TestFixtures.sampleMMCIF(residueCount: 10, chain: "B")
        // Splice the chain B atom rows into a single document.
        let combined = chainA.replacingOccurrences(of: "\n#", with: "\n") + "\n" + chainB
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("ATOM") }
            .joined(separator: "\n") + "\n#"
        let parts = ProteinStructurePart.make(from: combined)
        #expect(parts.contains { $0.chainID == "A" })
        #expect(parts.contains { $0.chainID == "B" })
    }

    // MARK: FocusedMolecularRegion

    @Test func focusedRegionContainsMembership() {
        let region = FocusedMolecularRegion(chainID: "A", startSequenceNumber: 5, endSequenceNumber: 10)
        func atom(chain: String, seq: Int?) -> MolecularAtom {
            MolecularAtom(atomName: "CA", element: "C", chainID: chain, sequenceNumber: seq, confidence: 90, position: SCNVector3Zero)
        }
        #expect(region.contains(atom(chain: "A", seq: 7)))
        #expect(region.contains(atom(chain: "A", seq: 5)))
        #expect(region.contains(atom(chain: "A", seq: 10)))
        #expect(!region.contains(atom(chain: "A", seq: 11)))
        #expect(!region.contains(atom(chain: "B", seq: 7)))
        #expect(!region.contains(atom(chain: "A", seq: nil)))
    }

    // MARK: StructureCache

    @Test func cacheRejectsTinyDownloads() async {
        let cache = StructureCache()
        await #expect(throws: AlphaFoldError.self) {
            _ = try await cache.store(data: Data("short".utf8), accession: "P0TINY", format: .mmcif)
        }
    }

    @Test func cacheStoresReadsAndReportsSizeThenClears() async throws {
        let cache = StructureCache()
        let payload = Data(TestFixtures.sampleMMCIF(residueCount: 6).utf8)
        let url = try await cache.store(data: payload, accession: "P0SIZE", format: .mmcif)
        #expect(await cache.cachedURL(accession: "P0SIZE", format: .mmcif) == url)
        #expect(await cache.size() > 0)
        try await cache.clear()
        #expect(await cache.cachedURL(accession: "P0SIZE", format: .mmcif) == nil)
        #expect(await cache.size() == 0)
    }

    // MARK: MolecularViewerViewModel

    @MainActor
    @Test func viewerModelLoadsStructureAndRecordsCache() async {
        let repo = InMemoryLibraryRepository()
        let protein = KnowledgeGraphStore.preview.protein(accession: "P69905")!
        let model = MolecularViewerViewModel(protein: protein, alphaFoldClient: StubAlphaFoldClient(), libraryRepository: repo)
        await model.load()
        guard case .loaded(_, let text) = model.state else {
            Issue.record("Expected loaded state, got \(model.state)")
            return
        }
        #expect(text.contains("ATOM"))
        #expect(!model.parts.isEmpty)
        #expect(repo.downloadedProteinAccessions.contains("P69905"))
    }

    @MainActor
    @Test func viewerModelReportsPredictionFailure() async {
        let protein = KnowledgeGraphStore.preview.protein(accession: "P69905")!
        let model = MolecularViewerViewModel(protein: protein, alphaFoldClient: StubAlphaFoldClient(failPrediction: true), libraryRepository: InMemoryLibraryRepository())
        await model.load()
        if case .failed = model.state {} else { Issue.record("Expected failed state") }
    }

    @MainActor
    @Test func viewerModelReportsEmptyStructureText() async {
        let protein = KnowledgeGraphStore.preview.protein(accession: "P69905")!
        let model = MolecularViewerViewModel(protein: protein, alphaFoldClient: StubAlphaFoldClient(structureText: "   "), libraryRepository: InMemoryLibraryRepository())
        await model.load()
        if case .failed = model.state {} else { Issue.record("Expected failed state for empty structure") }
    }

    @MainActor
    @Test func viewerModelSendIncrementsCommandSequence() {
        let protein = KnowledgeGraphStore.preview.protein(accession: "P69905")!
        let model = MolecularViewerViewModel(protein: protein, alphaFoldClient: StubAlphaFoldClient(), libraryRepository: InMemoryLibraryRepository())
        #expect(model.commandSequence == 0)
        model.send(.resetCamera)
        #expect(model.command == .resetCamera)
        #expect(model.commandSequence == 1)
        model.send(.setRepresentation(.surface))
        #expect(model.command == .setRepresentation(.surface))
        #expect(model.commandSequence == 2)
    }
}
