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
}
