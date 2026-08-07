import Foundation
import Testing
@testable import Molecyou

/// Coverage for formatting helpers, greetings, enums, analytics, and small model behaviors.
struct FormattingModelTests {
    // MARK: UnitFormatter

    @Test func energyFormattingAndConversion() {
        #expect(UnitFormatter.energy(nil) == "No data")
        #expect(UnitFormatter.energy(Measurement(value: 1842, unit: .kilocalories)) == "1842 kcal")
        // 4184 kJ == 1000 kcal.
        #expect(UnitFormatter.energy(Measurement(value: 4184, unit: .kilojoules)) == "1000 kcal")
    }

    @Test func heartRateFormatting() {
        #expect(UnitFormatter.heartRate(nil) == "No data")
        #expect(UnitFormatter.heartRate(Measurement(value: 58, unit: .beatsPerMinute)) == "58 bpm")
        #expect(UnitFormatter.heartRate(Measurement(value: 141.6, unit: .beatsPerMinute)) == "142 bpm")
    }

    @Test func sleepFormatting() {
        #expect(UnitFormatter.sleep(nil) == "No data")
        #expect(UnitFormatter.sleep(7.5 * 3600) == "7h 30m")
        #expect(UnitFormatter.sleep(0) == "0h 0m")
        #expect(UnitFormatter.sleep(6 * 3600 + 5 * 60) == "6h 5m")
    }

    @Test func percentFormatting() {
        #expect(UnitFormatter.percent(nil) == "No data")
        #expect(UnitFormatter.percent(0.975) == "98%")
        #expect(UnitFormatter.percent(0.5) == "50%")
        #expect(UnitFormatter.percent(1.0) == "100%")
    }

    @Test func respiratoryRateFormatting() {
        #expect(UnitFormatter.respiratoryRate(nil) == "No data")
        #expect(UnitFormatter.respiratoryRate(Measurement(value: 15.8, unit: .respirationsPerMinute)) == "15.8 rpm")
    }

    // MARK: GreetingGenerator

    private func date(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 18
        components.hour = hour
        components.minute = 0
        return Calendar.current.date(from: components)!
    }

    @Test func greetingRespectsTimeOfDayBoundaries() {
        #expect(GreetingGenerator.greeting(now: date(hour: 5), name: "Toby") == "Good morning, Toby")
        #expect(GreetingGenerator.greeting(now: date(hour: 11), name: "Toby") == "Good morning, Toby")
        #expect(GreetingGenerator.greeting(now: date(hour: 12), name: "Toby") == "Good afternoon, Toby")
        #expect(GreetingGenerator.greeting(now: date(hour: 16), name: "Toby") == "Good afternoon, Toby")
        #expect(GreetingGenerator.greeting(now: date(hour: 17), name: "Toby") == "Good evening, Toby")
        #expect(GreetingGenerator.greeting(now: date(hour: 23), name: "Toby") == "Good evening, Toby")
        #expect(GreetingGenerator.greeting(now: date(hour: 0), name: "Toby") == "Good evening, Toby")
        #expect(GreetingGenerator.greeting(now: date(hour: 4), name: "Toby") == "Good evening, Toby")
    }

    @Test func greetingUsesProvidedName() {
        #expect(GreetingGenerator.greeting(now: date(hour: 9), name: "Ada").hasSuffix(", Ada"))
    }

    // MARK: Enums (raw values are persisted / displayed and must stay stable)

    @Test func userInterestRawValues() {
        #expect(UserInterest.cardiovascular.rawValue == "Cardiovascular biology")
        #expect(UserInterest.exercise.rawValue == "Exercise and muscle")
        #expect(UserInterest.sleep.rawValue == "Sleep and circadian rhythm")
        #expect(UserInterest.general.rawValue == "General molecular biology")
        #expect(UserInterest.allCases.count == 8)
        #expect(UserInterest(rawValue: "Metabolism") == .metabolism)
    }

    @Test func relevanceLevelRawValues() {
        #expect(RelevanceLevel.high.rawValue == "High")
        #expect(RelevanceLevel.moderate.rawValue == "Moderate")
        #expect(RelevanceLevel.general.rawValue == "General interest")
    }

    @Test func structureFormatAndViewerEnums() {
        #expect(StructureFormat.mmcif.rawValue == "mmCIF")
        #expect(StructureFormat.bcif.rawValue == "BCIF")
        #expect(RepresentationType.allCases.map(\.id) == ["Ribbon", "Surface", "Ball + stick", "Atoms"])
        #expect(ColorMode.allCases.map(\.id) == ["Chain", "Element", "Confidence", "Uniform"])
    }

    @Test func biologicalSystemKindCoversUsedKinds() {
        let kinds = Set(BiologicalSystemKind.allCases.map(\.rawValue))
        #expect(kinds.isSuperset(of: ["cardiovascular", "respiratory", "musculoskeletal", "nervous", "endocrine", "immune", "renal", "metabolic", "circadian"]))
    }

    // MARK: Analytics

    @Test func analyticsScreenViewedFactoryAndEquatable() {
        let event = AnalyticsEvent.screenViewed("today")
        #expect(event.name == "screen_viewed")
        #expect(event.properties["screen"] == "today")
        #expect(event == AnalyticsEvent(name: "screen_viewed", properties: ["screen": "today"]))
        #expect(event != AnalyticsEvent(name: "screen_viewed", properties: ["screen": "explore"]))
    }

    @Test func noOpAnalyticsTrackerDoesNotCrash() {
        NoOpAnalyticsTracker().track(.screenViewed("anything"))
    }

    // MARK: AlphaFold response decoding

    @Test func alphaFoldResponseDerivesAccessionFromEntryIDWhenMissing() throws {
        let json = Data("""
        [{"entryId":"AF-P12345-F1","organismScientificName":"Homo sapiens","latestVersion":4,"globalMetricValue":88.2}]
        """.utf8)
        let decoded = try JSONDecoder().decode([AlphaFoldPredictionResponse].self, from: json)
        let model = decoded.first!.domainModel
        #expect(model.uniprotAccession == "P12345")
        #expect(model.entryID == "AF-P12345-F1")
        #expect(model.confidenceAverage == 88.2)
        #expect(model.license == "CC BY 4.0")
    }

    @Test func alphaFoldResponsePrefersExplicitAccession() throws {
        let json = Data("""
        [{"entryId":"AF-P68871-F1","uniprotAccession":"P68871","gene":"HBB","latestVersion":4}]
        """.utf8)
        let model = try JSONDecoder().decode([AlphaFoldPredictionResponse].self, from: json).first!.domainModel
        #expect(model.uniprotAccession == "P68871")
        #expect(model.gene == "HBB")
        #expect(model.confidenceAverage == nil)
    }

    // MARK: TodayViewModel

    @MainActor
    @Test func todayViewModelLoadsDemoSnapshot() async {
        let provider = FixedHealthProvider(snapshotValue: await DemoHealthDataProvider().snapshot())
        let model = TodayViewModel(healthProvider: provider, contextEngine: DefaultHealthContextEngine(), interests: [.exercise])
        await model.load()
        #expect(model.snapshot.isDemo)
        #expect(model.snapshot.workoutsThisWeek == 3)
        #expect(!model.recommendations.isEmpty)
        #expect(!model.isLoading)
    }

    @MainActor
    @Test func todayViewModelLoadsEmptyRealSnapshotWithFallback() async {
        let model = TodayViewModel(healthProvider: FixedHealthProvider(snapshotValue: .empty(isDemo: false)), contextEngine: DefaultHealthContextEngine(), interests: [.general])
        await model.load()
        #expect(!model.snapshot.isDemo)
        #expect(model.snapshot.workoutsThisWeek == nil)
        #expect(model.recommendations.first?.relevance == .general)
    }
}
