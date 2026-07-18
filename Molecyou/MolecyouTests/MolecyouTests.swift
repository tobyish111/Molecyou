import Foundation
import Testing
@testable import Molecyou

@MainActor
struct MolecyouTests {
    @Test func contextEngineRecommendsOxygenTransportForWorkouts() async throws {
        let snapshot = HealthSnapshot(generatedAt: .now, isDemo: true, workoutsThisWeek: 3, activeEnergyThisWeek: nil, averageWorkoutHeartRate: nil, restingHeartRate: nil, averageSleepDuration: nil, respiratoryRate: nil, oxygenSaturation: nil, vo2Max: nil)
        let recommendations = DefaultHealthContextEngine().evaluate(snapshot: snapshot, interests: [])
        #expect(recommendations.contains { $0.systemID == "oxygen-transport" && $0.relevance == .high })
        #expect(!recommendations.flatMap(\.reasons).contains { $0.localizedCaseInsensitiveContains("diagnosed") })
    }

    @Test func knowledgeGraphLoadsAtLeastTwentyFiveProteins() async throws {
        let graph = SeedKnowledgeGraph.make()
        #expect(graph.proteins.count >= 25)
        #expect(graph.proteins.contains { $0.uniprotAccession == "P68871" })
    }

    @Test func searchFindsHemoglobinByGeneAndAccession() async throws {
        let store = KnowledgeGraphStore.preview
        #expect(store.search("HBB").contains { $0.title.contains("Hemoglobin") })
        #expect(store.search("P68871").contains { $0.title == "Hemoglobin subunit beta" })
    }

    @Test func alphaFoldResponseDecodes() async throws {
        let json = """
        [{"entryId":"AF-P68871-F1","gene":"HBB","uniprotAccession":"P68871","organismScientificName":"Homo sapiens","latestVersion":4,"cifUrl":"https://example.com/model.cif","bcifUrl":"https://example.com/model.bcif","paeDocUrl":"https://example.com/pae.json","globalMetricValue":93.4}]
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([AlphaFoldPredictionResponse].self, from: json)
        #expect(decoded.first?.domainModel.uniprotAccession == "P68871")
        #expect(decoded.first?.domainModel.confidenceAverage == 93.4)
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
    }
}
