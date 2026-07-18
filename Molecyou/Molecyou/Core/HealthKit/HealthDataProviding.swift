import Foundation

protocol HealthDataProviding: Sendable {
    func authorizationState() async -> HealthAuthorizationState
    func requestAuthorization() async -> HealthAuthorizationState
    func snapshot() async -> HealthSnapshot
}

struct DemoHealthDataProvider: HealthDataProviding {
    func authorizationState() async -> HealthAuthorizationState { .available }
    func requestAuthorization() async -> HealthAuthorizationState { .available }

    func snapshot() async -> HealthSnapshot {
        HealthSnapshot(
            generatedAt: .now,
            isDemo: true,
            workoutsThisWeek: 3,
            activeEnergyThisWeek: Measurement(value: 1842, unit: .kilocalories),
            averageWorkoutHeartRate: Measurement(value: 142, unit: UnitFrequency.beatsPerMinute),
            restingHeartRate: Measurement(value: 54, unit: UnitFrequency.beatsPerMinute),
            averageSleepDuration: 7.4 * 3600,
            respiratoryRate: Measurement(value: 15.8, unit: UnitFrequency.respirationsPerMinute),
            oxygenSaturation: 0.98,
            vo2Max: 46.2
        )
    }
}

extension UnitFrequency {
    nonisolated static let beatsPerMinute = UnitFrequency(symbol: "bpm", converter: UnitConverterLinear(coefficient: 1.0 / 60.0))
    nonisolated static let respirationsPerMinute = UnitFrequency(symbol: "rpm", converter: UnitConverterLinear(coefficient: 1.0 / 60.0))
}
