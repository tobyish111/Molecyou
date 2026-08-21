import Foundation
import Testing
@testable import Molecyou

/// Exhaustive coverage of `DefaultHealthContextEngine.evaluate` across many simulated datasets.
/// This is the "recommend how-X-works topics from HealthKit/workout data" mechanism.
@MainActor
struct HealthContextEngineTests {
    private let engine = DefaultHealthContextEngine()

    private func systems(_ recs: [HealthContextRecommendation]) -> [String] { recs.map(\.systemID) }
    private func relevance(_ recs: [HealthContextRecommendation], _ id: String) -> RelevanceLevel? {
        recs.first { $0.systemID == id }?.relevance
    }

    // MARK: No data / interest-only

    @Test func emptyDataWithGeneralInterestFallsBackToOxygenTransportGeneral() {
        let recs = engine.evaluate(snapshot: TestSnapshot.make(), interests: [.general])
        #expect(recs.count == 1)
        #expect(recs.first?.systemID == "oxygen-transport")
        #expect(recs.first?.relevance == .general)
        #expect(recs.first?.reasons.contains { $0.contains("foundational") } == true)
    }

    @Test func emptyDataWithNoInterestsStillFallsBack() {
        let recs = engine.evaluate(snapshot: TestSnapshot.make(), interests: [])
        #expect(systems(recs) == ["oxygen-transport"])
        #expect(recs.first?.relevance == .general)
    }

    @Test func exerciseInterestAloneRecommendsMuscleContraction() {
        let recs = engine.evaluate(snapshot: TestSnapshot.make(), interests: [.exercise])
        #expect(systems(recs).contains("muscle-contraction"))
        // No oxygen-transport because no cardio/respiratory interest and no workouts.
        #expect(!systems(recs).contains("oxygen-transport"))
    }

    @Test func sleepInterestAloneRecommendsCircadian() {
        let recs = engine.evaluate(snapshot: TestSnapshot.make(), interests: [.sleep])
        #expect(systems(recs) == ["sleep-circadian"])
        #expect(relevance(recs, "sleep-circadian") == .moderate)
    }

    @Test func metabolismInterestAloneRecommendsCellularEnergy() {
        let recs = engine.evaluate(snapshot: TestSnapshot.make(), interests: [.metabolism])
        #expect(systems(recs) == ["cellular-energy"])
    }

    @Test func respiratoryInterestRecommendsOxygenAndRespiratory() {
        let recs = engine.evaluate(snapshot: TestSnapshot.make(), interests: [.respiratory])
        #expect(systems(recs).contains("oxygen-transport"))
        #expect(systems(recs).contains("respiratory-biology"))
        #expect(relevance(recs, "oxygen-transport") == .moderate)
    }

    // MARK: Workout thresholds

    @Test func twoOrMoreWorkoutsMakeOxygenAndMuscleHighRelevance() {
        let recs = engine.evaluate(snapshot: TestSnapshot.make(workouts: 3), interests: [])
        #expect(relevance(recs, "oxygen-transport") == .high)
        #expect(relevance(recs, "muscle-contraction") == .high)
        #expect(recs.first?.reasons.first?.contains("You recorded 3 workouts this week") == true)
    }

    @Test func singleWorkoutWithoutCardioInterestSkipsOxygenButKeepsMuscle() {
        let recs = engine.evaluate(snapshot: TestSnapshot.make(workouts: 1), interests: [])
        #expect(!systems(recs).contains("oxygen-transport"))
        #expect(relevance(recs, "muscle-contraction") == .moderate)
    }

    @Test func singleWorkoutWithCardioInterestUsesSingularReasonAndModerate() {
        let recs = engine.evaluate(snapshot: TestSnapshot.make(workouts: 1), interests: [.cardiovascular])
        #expect(relevance(recs, "oxygen-transport") == .moderate)
        let oxygen = recs.first { $0.systemID == "oxygen-transport" }
        #expect(oxygen?.reasons.first?.contains("You recorded 1 workout this week") == true)
        // Singular, not "1 workouts".
        #expect(oxygen?.reasons.first?.contains("1 workouts") == false)
    }

    // MARK: Individual signals

    @Test func sleepValueAloneRecommendsCircadian() {
        let recs = engine.evaluate(snapshot: TestSnapshot.make(sleepHours: 7.5), interests: [])
        #expect(systems(recs) == ["sleep-circadian"])
    }

    @Test func activeEnergyAloneRecommendsCellularEnergy() {
        let recs = engine.evaluate(snapshot: TestSnapshot.make(activeEnergyKcal: 1800), interests: [])
        #expect(systems(recs) == ["cellular-energy"])
    }

    @Test func respiratoryRateAloneRecommendsRespiratory() {
        let recs = engine.evaluate(snapshot: TestSnapshot.make(respiratoryRate: 15), interests: [])
        #expect(systems(recs) == ["respiratory-biology"])
    }

    @Test func oxygenSaturationAloneRecommendsRespiratory() {
        let recs = engine.evaluate(snapshot: TestSnapshot.make(oxygenSaturation: 0.97), interests: [])
        #expect(systems(recs) == ["respiratory-biology"])
    }

    // MARK: Rich dataset, dedup & ordering

    @Test func fullDatasetProducesEachSystemOnceInStableOrder() {
        let snapshot = TestSnapshot.make(
            workouts: 4,
            types: ["Running", "Cycling"],
            activeEnergyKcal: 2200,
            workoutHeartRate: 140,
            restingHeartRate: 57,
            sleepHours: 7.2,
            respiratoryRate: 16,
            oxygenSaturation: 0.98,
            vo2Max: 45
        )
        let recs = engine.evaluate(snapshot: snapshot, interests: Set(UserInterest.allCases))
        // No duplicates.
        #expect(Set(systems(recs)).count == systems(recs).count)
        // Expected ordering follows the engine's evaluation order.
        #expect(systems(recs) == ["oxygen-transport", "muscle-contraction", "sleep-circadian", "cellular-energy", "respiratory-biology"])
        #expect(relevance(recs, "oxygen-transport") == .high)
    }

    @Test func recommendationsNeverContainMedicalClaims() {
        let snapshot = TestSnapshot.make(workouts: 5, activeEnergyKcal: 3000, sleepHours: 6, respiratoryRate: 18)
        let recs = engine.evaluate(snapshot: snapshot, interests: Set(UserInterest.allCases))
        // Positive medical-claim phrases (disclaimers such as "not a respiratory diagnosis" are allowed).
        let bannedClaims = ["you have", "diagnoses you", "we detected", "treatment for", "prescrib", "cures "]
        for reason in recs.flatMap({ $0.reasons }) {
            for term in bannedClaims {
                #expect(!reason.localizedCaseInsensitiveContains(term), "Reason should not contain '\(term)': \(reason)")
            }
        }
    }

    @Test func recommendationIdentityMatchesSystemID() {
        let recs = engine.evaluate(snapshot: TestSnapshot.make(workouts: 2), interests: [])
        for rec in recs {
            #expect(rec.id == rec.systemID)
        }
    }
}
