import Foundation
import HealthKit

actor HealthKitManager: HealthDataProviding {
    private let healthStore = HKHealthStore()

    func authorizationState() async -> HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        do {
            let status = try await requestStatus()
            switch status {
            case .shouldRequest: return .notRequested
            case .unnecessary: return .requested
            case .unknown: return .requested
            @unknown default: return .requested
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func requestAuthorization() async -> HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            return .requested
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func snapshot() async -> HealthSnapshot {
        guard HKHealthStore.isHealthDataAvailable() else {
            return HealthSnapshot.empty(isDemo: false)
        }

        async let workouts = workoutsThisWeek()
        async let workoutTypes = workoutTypesThisWeek()
        async let energy = quantitySum(.activeEnergyBurned, unit: .kilocalorie(), days: 7)
        async let resting = quantityAverage(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), days: 14)
        async let sleep = averageSleepDuration(days: 7)
        async let respiratory = quantityAverage(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), days: 14)
        async let oxygen = quantityAverage(.oxygenSaturation, unit: .percent(), days: 14)
        async let vo2 = quantityAverage(.vo2Max, unit: HKUnit(from: "mL/kg*min"), days: 90)

        return HealthSnapshot(
            generatedAt: .now,
            isDemo: false,
            workoutsThisWeek: await workouts,
            workoutTypesThisWeek: await workoutTypes,
            activeEnergyThisWeek: await energy.map { Measurement(value: $0, unit: .kilocalories) },
            averageWorkoutHeartRate: nil,
            restingHeartRate: await resting.map { Measurement(value: $0, unit: UnitFrequency.beatsPerMinute) },
            averageSleepDuration: await sleep,
            respiratoryRate: await respiratory.map { Measurement(value: $0, unit: UnitFrequency.respirationsPerMinute) },
            oxygenSaturation: await oxygen.map { $0 / 100.0 },
            vo2Max: await vo2
        )
    }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        let identifiers: [HKQuantityTypeIdentifier] = [
            .activeEnergyBurned,
            .heartRate,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .walkingHeartRateAverage,
            .respiratoryRate,
            .oxygenSaturation,
            .vo2Max
        ]
        for identifier in identifiers {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }

    private func requestStatus() async throws -> HKAuthorizationRequestStatus {
        try await withCheckedThrowingContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    private func workoutsThisWeek() async -> Int? {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -7, to: .now), end: .now)
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard error == nil else { continuation.resume(returning: nil); return }
                continuation.resume(returning: samples?.count)
            }
            healthStore.execute(query)
        }
    }

    private func workoutTypesThisWeek() async -> [String] {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -7, to: .now), end: .now)
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                let workouts = samples as? [HKWorkout] ?? []
                let names = workouts.map { Self.displayName(for: $0.workoutActivityType) }
                let uniqueNames = Array(Set(names)).sorted()
                continuation.resume(returning: uniqueNames)
            }
            healthStore.execute(query)
        }
    }

    private nonisolated static func displayName(for activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .americanFootball: "American Football"
        case .archery: "Archery"
        case .australianFootball: "Australian Football"
        case .badminton: "Badminton"
        case .barre: "Barre"
        case .baseball: "Baseball"
        case .basketball: "Basketball"
        case .bowling: "Bowling"
        case .boxing: "Boxing"
        case .climbing: "Climbing"
        case .coreTraining: "Core Training"
        case .cricket: "Cricket"
        case .crossTraining: "Cross Training"
        case .curling: "Curling"
        case .cycling: "Cycling"
        case .dance: "Dance"
        case .danceInspiredTraining: "Dance"
        case .discSports: "Disc Sports"
        case .downhillSkiing: "Downhill Skiing"
        case .elliptical: "Elliptical"
        case .equestrianSports: "Equestrian Sports"
        case .fencing: "Fencing"
        case .fishing: "Fishing"
        case .fitnessGaming: "Fitness Gaming"
        case .flexibility: "Flexibility"
        case .functionalStrengthTraining: "Functional Strength Training"
        case .golf: "Golf"
        case .gymnastics: "Gymnastics"
        case .handCycling: "Hand Cycling"
        case .handball: "Handball"
        case .highIntensityIntervalTraining: "HIIT"
        case .hiking: "Hiking"
        case .hockey: "Hockey"
        case .hunting: "Hunting"
        case .jumpRope: "Jump Rope"
        case .kickboxing: "Kickboxing"
        case .lacrosse: "Lacrosse"
        case .martialArts: "Martial Arts"
        case .mindAndBody: "Mind and Body"
        case .mixedCardio: "Mixed Cardio"
        case .other: "Other Workout"
        case .paddleSports: "Paddle Sports"
        case .pickleball: "Pickleball"
        case .pilates: "Pilates"
        case .play: "Play"
        case .preparationAndRecovery: "Preparation and Recovery"
        case .racquetball: "Racquetball"
        case .rowing: "Rowing"
        case .rugby: "Rugby"
        case .running: "Running"
        case .sailing: "Sailing"
        case .skatingSports: "Skating Sports"
        case .snowSports: "Snow Sports"
        case .snowboarding: "Snowboarding"
        case .soccer: "Soccer"
        case .socialDance: "Social Dance"
        case .softball: "Softball"
        case .squash: "Squash"
        case .stairClimbing: "Stair Climbing"
        case .stairs: "Stairs"
        case .stepTraining: "Step Training"
        case .surfingSports: "Surfing"
        case .swimming: "Swimming"
        case .tableTennis: "Table Tennis"
        case .taiChi: "Tai Chi"
        case .tennis: "Tennis"
        case .trackAndField: "Track and Field"
        case .traditionalStrengthTraining: "Traditional Strength Training"
        case .volleyball: "Volleyball"
        case .walking: "Walking"
        case .waterFitness: "Water Fitness"
        case .waterPolo: "Water Polo"
        case .waterSports: "Water Sports"
        case .wrestling: "Wrestling"
        case .yoga: "Yoga"
        default: "Workout"
        }
    }

    private func quantitySum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -days, to: .now), end: .now)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                guard error == nil else { continuation.resume(returning: nil); return }
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func quantityAverage(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -days, to: .now), end: .now)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, error in
                guard error == nil else { continuation.resume(returning: nil); return }
                continuation.resume(returning: statistics?.averageQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func averageSleepDuration(days: Int) async -> TimeInterval? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -days, to: .now), end: .now)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard error == nil else { continuation.resume(returning: nil); return }
                let durations = (samples as? [HKCategorySample] ?? [])
                    .filter { sample in
                        sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue || sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue || sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue || sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    }
                    .map { $0.endDate.timeIntervalSince($0.startDate) }
                guard !durations.isEmpty else { continuation.resume(returning: nil); return }
                continuation.resume(returning: durations.reduce(0, +) / Double(days))
            }
            healthStore.execute(query)
        }
    }
}

extension HealthSnapshot {
    nonisolated static func empty(isDemo: Bool) -> HealthSnapshot {
        HealthSnapshot(generatedAt: .now, isDemo: isDemo, workoutsThisWeek: nil, workoutTypesThisWeek: [], activeEnergyThisWeek: nil, averageWorkoutHeartRate: nil, restingHeartRate: nil, averageSleepDuration: nil, respiratoryRate: nil, oxygenSaturation: nil, vo2Max: nil)
    }
}
