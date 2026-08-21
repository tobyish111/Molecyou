import Foundation
import Testing
@testable import Molecyou

/// Coverage for `HealthSnapshot.matchingEvidence(for:)` — the per-system explanation cards.
struct HealthEvidenceTests {
    private func ids(_ evidence: [HealthContextEvidence]) -> [String] { evidence.map(\.id) }

    @Test func oxygenTransportSurfacesWorkoutOxygenAndEnergyEvidence() {
        let snapshot = TestSnapshot.make(workouts: 3, types: ["Running"], activeEnergyKcal: 2000, oxygenSaturation: 0.98)
        let evidence = snapshot.matchingEvidence(for: "oxygen-transport")
        #expect(ids(evidence).contains("workouts"))
        #expect(ids(evidence).contains("oxygen-saturation"))
        #expect(ids(evidence).contains("active-energy"))
    }

    @Test func muscleContractionIncludesWorkoutHeartRateWhenAvailable() {
        let snapshot = TestSnapshot.make(workouts: 2, types: ["Cycling"], activeEnergyKcal: 1500, workoutHeartRate: 138)
        let evidence = snapshot.matchingEvidence(for: "muscle-contraction")
        #expect(ids(evidence).contains("workout-heart-rate"))
        #expect(evidence.contains { $0.detail.contains("this matches muscle contraction") })
    }

    @Test func sleepCircadianOnlySurfacesSleepEvidence() {
        let snapshot = TestSnapshot.make(workouts: 4, sleepHours: 7.4)
        let evidence = snapshot.matchingEvidence(for: "sleep-circadian")
        #expect(ids(evidence) == ["sleep"])
        #expect(evidence.first?.detail.contains("this matches circadian timing") == true)
    }

    @Test func respiratorySurfacesRespiratoryRateAndOxygen() {
        let snapshot = TestSnapshot.make(respiratoryRate: 16, oxygenSaturation: 0.97)
        let evidence = snapshot.matchingEvidence(for: "respiratory-biology")
        #expect(ids(evidence).contains("respiratory-rate"))
        #expect(ids(evidence).contains("oxygen-saturation"))
    }

    @Test func cardiacSignalingSurfacesRestingHeartRate() {
        let snapshot = TestSnapshot.make(workouts: 1, restingHeartRate: 55)
        let evidence = snapshot.matchingEvidence(for: "cardiac-signaling")
        #expect(ids(evidence).contains("resting-heart-rate"))
    }

    @Test func unknownSystemUsesDefaultActivityEvidence() {
        let snapshot = TestSnapshot.make(workouts: 2, activeEnergyKcal: 900, sleepHours: 8)
        let evidence = snapshot.matchingEvidence(for: "immune-defense")
        #expect(ids(evidence).contains("workouts"))
        #expect(ids(evidence).contains("active-energy"))
        #expect(ids(evidence).contains("sleep"))
    }

    // MARK: Empty-data fallback

    @Test func noSignalsInDemoModeShowsDemoPlaceholder() {
        let snapshot = TestSnapshot.make(isDemo: true)
        let evidence = snapshot.matchingEvidence(for: "oxygen-transport")
        #expect(evidence.count == 1)
        #expect(evidence.first?.id == "no-specific-signal")
        #expect(evidence.first?.value == "Demo mode")
    }

    @Test func noSignalsInRealModeShowsNoDataPlaceholder() {
        let snapshot = TestSnapshot.make(isDemo: false)
        let evidence = snapshot.matchingEvidence(for: "oxygen-transport")
        #expect(evidence.first?.id == "no-specific-signal")
        #expect(evidence.first?.value == "No data")
    }

    // MARK: Workout-type phrasing

    @Test func singleWorkoutTypePhrasing() {
        let snapshot = TestSnapshot.make(workouts: 1, types: ["Running"])
        let detail = snapshot.matchingEvidence(for: "muscle-contraction").first { $0.id == "workouts" }?.detail
        #expect(detail?.contains("Because you logged a Running workout this week (1 workout this week)") == true)
    }

    @Test func twoWorkoutTypePhrasing() {
        let snapshot = TestSnapshot.make(workouts: 2, types: ["Running", "Cycling"])
        let detail = snapshot.matchingEvidence(for: "muscle-contraction").first { $0.id == "workouts" }?.detail
        #expect(detail?.contains("Running and Cycling workouts this week") == true)
        #expect(detail?.contains("(2 workouts this week)") == true)
    }

    @Test func threePlusWorkoutTypePhrasingUsesOxfordComma() {
        let snapshot = TestSnapshot.make(workouts: 3, types: ["Running", "Cycling", "Swimming"])
        let detail = snapshot.matchingEvidence(for: "muscle-contraction").first { $0.id == "workouts" }?.detail
        #expect(detail?.contains("Running, Cycling, and Swimming workouts") == true)
    }

    @Test func workoutsWithoutTypeMentionsMissingType() {
        let snapshot = TestSnapshot.make(workouts: 2, types: [])
        let detail = snapshot.matchingEvidence(for: "muscle-contraction").first { $0.id == "workouts" }?.detail
        #expect(detail?.contains("HealthKit did not provide a workout type") == true)
    }

    @Test func zeroWorkoutsProducesNoWorkoutEvidence() {
        let snapshot = TestSnapshot.make(workouts: 0, activeEnergyKcal: 500)
        let evidence = snapshot.matchingEvidence(for: "oxygen-transport")
        #expect(!ids(evidence).contains("workouts"))
        #expect(ids(evidence).contains("active-energy"))
    }
}
