import Foundation
import Testing
@testable import Molecyou

@MainActor
struct MolecyouTests {
    @Test func demoProviderReturnsLabeledDemoValues() async throws {
        let snapshot = await DemoHealthDataProvider().snapshot()
        #expect(snapshot.isDemo)
        #expect(snapshot.workoutsThisWeek == 3)
        #expect(UnitFormatter.energy(snapshot.activeEnergyThisWeek) == "1842 kcal")
    }

    @Test func noHealthDataStillProducesEducationalRecommendation() async throws {
        let snapshot = HealthSnapshot.empty(isDemo: false)
        let recommendations = DefaultHealthContextEngine().evaluate(snapshot: snapshot, interests: [.general])
        #expect(recommendations.count == 1)
        #expect(recommendations.first?.systemID == "oxygen-transport")
        #expect(recommendations.first?.relevance == .general)
        #expect(recommendations.flatMap(\.reasons).contains { $0.contains("foundational") })
    }

    @Test func linkedHealthSnapshotProducesRelevantSystemsWithoutMedicalClaims() async throws {
        let snapshot = HealthSnapshot(
            generatedAt: .now,
            isDemo: false,
            workoutsThisWeek: 4,
            workoutTypesThisWeek: ["Running", "Cycling"],
            activeEnergyThisWeek: Measurement(value: 2200, unit: .kilocalories),
            averageWorkoutHeartRate: Measurement(value: 141, unit: .beatsPerMinute),
            restingHeartRate: Measurement(value: 58, unit: .beatsPerMinute),
            averageSleepDuration: 7.2 * 3600,
            respiratoryRate: Measurement(value: 16, unit: .respirationsPerMinute),
            oxygenSaturation: 0.98,
            vo2Max: 45
        )
        let recommendations = DefaultHealthContextEngine().evaluate(snapshot: snapshot, interests: [.exercise, .sleep, .metabolism, .respiratory])
        #expect(recommendations.contains { $0.systemID == "oxygen-transport" && $0.relevance == .high })
        #expect(recommendations.contains { $0.systemID == "muscle-contraction" })
        #expect(recommendations.contains { $0.systemID == "sleep-circadian" })
        #expect(!recommendations.flatMap(\.reasons).contains { reason in
            ["diagnose", "diagnosed", "protein activity", "malformed", "treatment"].contains { reason.localizedCaseInsensitiveContains($0) }
        })
    }

    @Test func healthContextEvidenceReadsNaturally() async throws {
        let snapshot = HealthSnapshot(
            generatedAt: .now,
            isDemo: false,
            workoutsThisWeek: 2,
            workoutTypesThisWeek: ["Running", "Cycling"],
            activeEnergyThisWeek: nil,
            averageWorkoutHeartRate: nil,
            restingHeartRate: nil,
            averageSleepDuration: 7.4 * 3600,
            respiratoryRate: nil,
            oxygenSaturation: nil,
            vo2Max: nil
        )
        let workoutEvidence = snapshot.matchingEvidence(for: "muscle-contraction")
        #expect(workoutEvidence.contains { $0.detail.contains("Because you logged Running and Cycling workouts") })
        #expect(workoutEvidence.contains { $0.detail.contains("this matches muscle contraction") })

        let sleepEvidence = snapshot.matchingEvidence(for: "sleep-circadian")
        #expect(sleepEvidence.contains { $0.detail.contains("Because your average sleep duration was") })
        #expect(sleepEvidence.contains { $0.detail.contains("this matches circadian timing") })
    }

    @Test func todayViewModelKeepsDemoAndRealSnapshotsSeparate() async throws {
        let demoModel = TodayViewModel(healthProvider: StubHealthProvider(snapshot: await DemoHealthDataProvider().snapshot()), contextEngine: DefaultHealthContextEngine(), interests: [.exercise])
        await demoModel.load()
        #expect(demoModel.snapshot.isDemo)
        #expect(demoModel.snapshot.workoutsThisWeek == 3)

        let realEmptyModel = TodayViewModel(healthProvider: StubHealthProvider(snapshot: .empty(isDemo: false)), contextEngine: DefaultHealthContextEngine(), interests: [.general])
        await realEmptyModel.load()
        #expect(!realEmptyModel.snapshot.isDemo)
        #expect(realEmptyModel.snapshot.workoutsThisWeek == nil)
        #expect(realEmptyModel.recommendations.first?.relevance == .general)
    }

    @Test func knowledgeGraphLoadsAtLeastTwentyFiveProteinsAndCoreSystems() async throws {
        let graph = SeedKnowledgeGraph.make()
        #expect(graph.proteins.count >= 25)
        #expect(graph.systems.contains { $0.id == "oxygen-transport" })
        #expect(graph.proteins.contains { $0.uniprotAccession == "P68871" })
        #expect(graph.proteins.contains { $0.geneSymbol == "CLOCK" })
    }

    @Test func educationModulesAllHaveHowItWorksSteps() async throws {
        let graph = SeedKnowledgeGraph.make()
        #expect(graph.modules.allSatisfy { $0.title.hasPrefix("How ") })
        #expect(graph.modules.allSatisfy { $0.steps.count >= 3 })
        #expect(graph.modules.allSatisfy { $0.sourceIDs == ["uniprot"] })
    }

    @Test func searchFindsEducationByGeneAccessionAndSystem() async throws {
        let store = KnowledgeGraphStore.preview
        #expect(store.search("HBB").contains { $0.title.contains("Hemoglobin") })
        #expect(store.search("P68871").contains { $0.title == "Hemoglobin subunit beta" })
        #expect(store.search("circadian").contains { $0.title.contains("Circadian") || $0.subtitle.contains("circadian") })
        #expect(store.search("ZZZ_NOT_FOUND").isEmpty)
    }

    @Test func inMemoryLibrarySupportsSaveNotesAndCacheState() async throws {
        let repository = InMemoryLibraryRepository()
        #expect(!repository.isProteinSaved("P68871"))
        repository.toggleProteinSaved("P68871")
        #expect(repository.isProteinSaved("P68871"))
        repository.addNote(itemID: "P68871", itemType: "protein", text: "Review oxygen binding")
        #expect(repository.notes.count == 1)
        repository.recordCachedStructure(accession: "P68871", url: URL(filePath: "/tmp/P68871.cif"), format: .mmcif, bytes: 128)
        #expect(repository.downloadedProteinAccessions.contains("P68871"))
        try repository.clearCachedStructures()
        #expect(repository.downloadedProteinAccessions.isEmpty)
    }

    @Test func structureCacheStoresDistinctFilesByAccession() async throws {
        let cache = StructureCache()
        let firstCIF = "data_one\n#\nATOM 1 C CA ALA A 1 0 0 0\n" + String(repeating: "# cache fixture padding\n", count: 4)
        let secondCIF = "data_two\n#\nATOM 1 C CA GLY A 1 1 1 1\n" + String(repeating: "# cache fixture padding\n", count: 4)
        let firstURL = try await cache.store(data: Data(firstCIF.utf8), accession: "P68871", format: .mmcif)
        let secondURL = try await cache.store(data: Data(secondCIF.utf8), accession: "P69905", format: .mmcif)
        #expect(firstURL != secondURL)
        #expect(await cache.cachedURL(accession: "P68871", format: .mmcif) == firstURL)
        try await cache.clear()
    }

    @Test func alphaFoldResponseDecodesAndNoResultIsRepresented() async throws {
        let json = """
        [{"entryId":"AF-P68871-F1","gene":"HBB","uniprotAccession":"P68871","organismScientificName":"Homo sapiens","latestVersion":4,"cifUrl":"https://example.com/model.cif","bcifUrl":"https://example.com/model.bcif","paeDocUrl":"https://example.com/pae.json","globalMetricValue":93.4}]
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([AlphaFoldPredictionResponse].self, from: json)
        #expect(decoded.first?.domainModel.uniprotAccession == "P68871")
        #expect(decoded.first?.domainModel.confidenceAverage == 93.4)

        do {
            _ = try await FailingAlphaFoldClient().prediction(for: "NO_RESULT")
            Issue.record("Expected no AlphaFold result")
        } catch AlphaFoldError.noPrediction(let accession) {
            #expect(accession == "NO_RESULT")
        }
    }

    @Test func molecularViewerViewModelLoadsDifferentStructureTextPerProtein() async throws {
        let repository = InMemoryLibraryRepository()
        let proteins = KnowledgeGraphStore.preview.proteins
        let first = proteins.first { $0.uniprotAccession == "P68871" }!
        let second = proteins.first { $0.uniprotAccession == "P69905" }!
        let client = DistinctStructureAlphaFoldClient()

        let firstModel = MolecularViewerViewModel(protein: first, alphaFoldClient: client, libraryRepository: repository)
        await firstModel.load()
        let secondModel = MolecularViewerViewModel(protein: second, alphaFoldClient: client, libraryRepository: repository)
        await secondModel.load()

        guard case .loaded(_, let firstText) = firstModel.state, case .loaded(_, let secondText) = secondModel.state else {
            Issue.record("Expected both viewer models to load")
            return
        }
        #expect(firstText.contains("data_P68871"))
        #expect(secondText.contains("data_P69905"))
        #expect(firstText != secondText)
    }

    @Test func greetingUsesTimeOfDay() async throws {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = 2026
        components.month = 7
        components.day = 18
        components.hour = 8
        let date = components.date!
        #expect(GreetingGenerator.greeting(now: date, name: "Toby") == "Good morning, Toby")
    }

    @Test func unitFormattingKeepsDemoAndMissingDataSeparate() async throws {
        #expect(UnitFormatter.energy(nil) == "No data")
        #expect(UnitFormatter.sleep(7.5 * 3600) == "7h 30m")
        #expect(UnitFormatter.percent(0.975) == "98%")
    }
}

private struct StubHealthProvider: HealthDataProviding {
    let snapshot: HealthSnapshot
    func authorizationState() async -> HealthAuthorizationState { .available }
    func requestAuthorization() async -> HealthAuthorizationState { .available }
    func snapshot() async -> HealthSnapshot { snapshot }
}

private struct FailingAlphaFoldClient: AlphaFoldDBProviding {
    func prediction(for accession: String) async throws -> AlphaFoldPrediction {
        throw AlphaFoldError.noPrediction(accession)
    }

    func downloadStructure(for prediction: AlphaFoldPrediction, format: StructureFormat) async throws -> URL {
        throw AlphaFoldError.missingStructureURL
    }
}

private struct DistinctStructureAlphaFoldClient: AlphaFoldDBProviding {
    func prediction(for accession: String) async throws -> AlphaFoldPrediction {
        AlphaFoldPrediction(uniprotAccession: accession, entryID: "AF-\(accession)-F1", gene: nil, organismScientificName: "Homo sapiens", latestVersion: 4, cifURL: nil, bcifURL: nil, paeDocURL: nil, confidenceAverage: 90, license: "CC BY 4.0")
    }

    func downloadStructure(for prediction: AlphaFoldPrediction, format: StructureFormat) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(prediction.uniprotAccession)-test.cif")
        let content = """
        data_\(prediction.uniprotAccession)
        #
        loop_
        _atom_site.group_PDB
        _atom_site.id
        _atom_site.type_symbol
        _atom_site.label_atom_id
        _atom_site.label_comp_id
        _atom_site.label_asym_id
        _atom_site.label_seq_id
        _atom_site.Cartn_x
        _atom_site.Cartn_y
        _atom_site.Cartn_z
        ATOM 1 C CA ALA A 1 0.000 0.000 0.000
        #
        """
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
