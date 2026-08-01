import Foundation

protocol HealthContextEvaluating: Sendable {
    func evaluate(snapshot: HealthSnapshot, interests: Set<UserInterest>) -> [HealthContextRecommendation]
}

struct DefaultHealthContextEngine: HealthContextEvaluating {
    func evaluate(snapshot: HealthSnapshot, interests: Set<UserInterest>) -> [HealthContextRecommendation] {
        var recommendations: [HealthContextRecommendation] = []

        let workoutCount = snapshot.workoutsThisWeek ?? 0
        if workoutCount >= 2 || interests.contains(.cardiovascular) || interests.contains(.respiratory) {
            var reasons = ["Oxygen transport is an important general concept in sustained activity."]
            if workoutCount > 0 {
                reasons.insert("You recorded \(workoutCount) workout\(workoutCount == 1 ? "" : "s") this week.", at: 0)
            }
            recommendations.append(HealthContextRecommendation(systemID: "oxygen-transport", relevance: workoutCount >= 2 ? .high : .moderate, reasons: reasons))
        }

        if workoutCount > 0 || interests.contains(.exercise) {
            recommendations.append(HealthContextRecommendation(systemID: "muscle-contraction", relevance: workoutCount >= 2 ? .high : .moderate, reasons: [
                "Your recent activity makes muscle contraction a useful system to explore.",
                "Actin, myosin, calcium handling, and ATP are general concepts in movement."
            ]))
        }

        if snapshot.averageSleepDuration != nil || interests.contains(.sleep) {
            recommendations.append(HealthContextRecommendation(systemID: "sleep-circadian", relevance: .moderate, reasons: [
                "Sleep records can make circadian timing relevant to learn about.",
                "Circadian proteins help explain daily biological timing in general education."
            ]))
        }

        if snapshot.activeEnergyThisWeek != nil || interests.contains(.metabolism) {
            recommendations.append(HealthContextRecommendation(systemID: "cellular-energy", relevance: .moderate, reasons: [
                "Activity energy can be an entry point for learning how cells use fuel.",
                "This app does not calculate a metabolic health score."
            ]))
        }

        if snapshot.respiratoryRate != nil || snapshot.oxygenSaturation != nil || interests.contains(.respiratory) {
            recommendations.append(HealthContextRecommendation(systemID: "respiratory-biology", relevance: .moderate, reasons: [
                "Available breathing-related categories can make gas exchange useful to explore.",
                "This is educational context, not a respiratory diagnosis."
            ]))
        }

        if recommendations.isEmpty {
            recommendations.append(HealthContextRecommendation(systemID: "oxygen-transport", relevance: .general, reasons: [
                "You selected general molecular biology topics.",
                "Oxygen transport is a foundational system for understanding physiology."
            ]))
        }

        var seen = Set<String>()
        return recommendations.filter { seen.insert($0.systemID).inserted }
    }
}

struct HealthContextEvidence: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let symbol: String
}

extension HealthSnapshot {
    nonisolated func matchingEvidence(for systemID: String) -> [HealthContextEvidence] {
        switch systemID {
        case "oxygen-transport":
            return compactEvidence([
                workoutEvidence(matchReason: "oxygen transport because sustained activity depends on breathing, blood flow, and oxygen delivery"),
                oxygenEvidence(matchReason: "oxygen transport because oxygen saturation is part of breathing and blood oxygen education"),
                activeEnergyEvidence(matchReason: "oxygen transport because active energy can point toward oxygen delivery and energy use during activity")
            ])
        case "muscle-contraction":
            return compactEvidence([
                workoutEvidence(matchReason: "muscle contraction because movement depends on actin, myosin, calcium handling, and ATP"),
                activeEnergyEvidence(matchReason: "muscle contraction because active energy is related to ATP demand during movement"),
                averageWorkoutHeartRate.map { HealthContextEvidence(id: "workout-heart-rate", title: "Workout heart rate", value: UnitFormatter.heartRate($0), detail: "Because your average workout heart rate was \(UnitFormatter.heartRate($0)), this matches recent exercise context, not muscle protein activity.", symbol: "heart") }
            ])
        case "sleep-circadian":
            return compactEvidence([
                averageSleepDuration.map { HealthContextEvidence(id: "sleep", title: "Sleep duration", value: UnitFormatter.sleep($0), detail: "Because your average sleep duration was \(UnitFormatter.sleep($0)), this matches circadian timing because sleep is one of the clearest daily rhythm signals.", symbol: "moon") }
            ])
        case "cellular-energy":
            return compactEvidence([
                activeEnergyEvidence(matchReason: "cellular energy because active energy reflects recent energy demand"),
                workoutEvidence(matchReason: "cellular energy because activity raises fuel use and ATP demand")
            ])
        case "respiratory-biology":
            return compactEvidence([
                respiratoryRate.map { HealthContextEvidence(id: "respiratory-rate", title: "Respiratory rate", value: UnitFormatter.respiratoryRate($0), detail: "Because your respiratory rate was \(UnitFormatter.respiratoryRate($0)), this matches gas exchange because breathing rate is a respiratory context signal.", symbol: "lungs") },
                oxygenEvidence(matchReason: "respiratory biology because oxygen saturation is a breathing-related HealthKit category")
            ])
        case "cardiac-signaling":
            return compactEvidence([
                restingHeartRate.map { HealthContextEvidence(id: "resting-heart-rate", title: "Resting heart rate", value: UnitFormatter.heartRate($0), detail: "Because your resting heart rate was \(UnitFormatter.heartRate($0)), this matches cardiac signaling because heart response is tied to cardiovascular regulation.", symbol: "heart") },
                workoutEvidence(matchReason: "cardiac signaling because heart response changes with activity")
            ])
        default:
            return compactEvidence([
                workoutEvidence(matchReason: "this biology topic as recent activity context"),
                activeEnergyEvidence(matchReason: "this biology topic because active energy is a broad activity context signal"),
                averageSleepDuration.map { HealthContextEvidence(id: "sleep", title: "Sleep duration", value: UnitFormatter.sleep($0), detail: "Because your average sleep duration was \(UnitFormatter.sleep($0)), this can match timing, recovery, and regulation topics.", symbol: "moon") }
            ])
        }
    }

    private nonisolated func compactEvidence(_ items: [HealthContextEvidence?]) -> [HealthContextEvidence] {
        let evidence = items.compactMap { $0 }
        if evidence.isEmpty {
            return [
                HealthContextEvidence(
                    id: "no-specific-signal",
                    title: "No specific HealthKit value",
                    value: isDemo ? "Demo mode" : "No data",
                    detail: "This topic is shown from selected educational interests or bundled app content, not a specific recorded workout.",
                    symbol: "info.circle"
                )
            ]
        }
        return evidence
    }

    private nonisolated func workoutEvidence(matchReason: String) -> HealthContextEvidence? {
        guard let workoutsThisWeek, workoutsThisWeek > 0 else { return nil }
        let detail: String
        if workoutTypesThisWeek.isEmpty {
            detail = "Because you logged \(workoutCountText), this matches \(matchReason). HealthKit did not provide a workout type for those sessions."
        } else {
            detail = "Because you logged \(workoutTypeText) this week (\(workoutCountText)), this matches \(matchReason)."
        }
        return HealthContextEvidence(
            id: "workouts",
            title: "Workouts this week",
            value: "\(workoutsThisWeek)",
            detail: detail,
            symbol: "figure.run"
        )
    }

    private nonisolated var workoutCountText: String {
        guard let workoutsThisWeek else { return "workouts this week" }
        return "\(workoutsThisWeek) workout\(workoutsThisWeek == 1 ? "" : "s") this week"
    }

    private nonisolated var workoutTypeText: String {
        switch workoutTypesThisWeek.count {
        case 0:
            return "workouts"
        case 1:
            return "a \(workoutTypesThisWeek[0]) workout"
        case 2:
            return "\(workoutTypesThisWeek[0]) and \(workoutTypesThisWeek[1]) workouts"
        default:
            let leadingTypes = workoutTypesThisWeek.dropLast().joined(separator: ", ")
            return "\(leadingTypes), and \(workoutTypesThisWeek.last ?? "") workouts"
        }
    }

    private nonisolated func activeEnergyEvidence(matchReason: String) -> HealthContextEvidence? {
        activeEnergyThisWeek.map {
            HealthContextEvidence(id: "active-energy", title: "Active energy", value: UnitFormatter.energy($0), detail: "Because your active energy this week was \(UnitFormatter.energy($0)), this matches \(matchReason).", symbol: "flame")
        }
    }

    private nonisolated func oxygenEvidence(matchReason: String) -> HealthContextEvidence? {
        oxygenSaturation.map {
            HealthContextEvidence(id: "oxygen-saturation", title: "Oxygen saturation", value: UnitFormatter.percent($0), detail: "Because your oxygen saturation was \(UnitFormatter.percent($0)), this matches \(matchReason).", symbol: "lungs")
        }
    }
}

enum GreetingGenerator {
    nonisolated static func greeting(now: Date = .now, name: String) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        let part: String
        switch hour {
        case 5..<12: part = "Good morning"
        case 12..<17: part = "Good afternoon"
        default: part = "Good evening"
        }
        return "\(part), \(name)"
    }
}

enum UnitFormatter {
    nonisolated static func energy(_ measurement: Measurement<UnitEnergy>?) -> String {
        guard let measurement else { return "No data" }
        return "\(Int(measurement.converted(to: .kilocalories).value.rounded())) kcal"
    }

    nonisolated static func heartRate(_ measurement: Measurement<UnitFrequency>?) -> String {
        guard let measurement else { return "No data" }
        return "\(Int(measurement.value.rounded())) bpm"
    }

    nonisolated static func sleep(_ interval: TimeInterval?) -> String {
        guard let interval else { return "No data" }
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }

    nonisolated static func percent(_ value: Double?) -> String {
        guard let value else { return "No data" }
        return "\(Int((value * 100).rounded()))%"
    }

    nonisolated static func respiratoryRate(_ measurement: Measurement<UnitFrequency>?) -> String {
        guard let measurement else { return "No data" }
        return String(format: "%.1f rpm", measurement.value)
    }
}
