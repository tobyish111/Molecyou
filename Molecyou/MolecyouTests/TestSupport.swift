import Foundation
import SwiftData
@testable import Molecyou

// MARK: - Shared test doubles and fixtures used across the unit test suites.

/// A health provider that returns a fixed snapshot and configurable authorization state.
struct FixedHealthProvider: HealthDataProviding {
    var snapshotValue: HealthSnapshot
    var authState: HealthAuthorizationState = .available

    func authorizationState() async -> HealthAuthorizationState { authState }
    func requestAuthorization() async -> HealthAuthorizationState { authState }
    func snapshot() async -> HealthSnapshot { snapshotValue }
}

/// An AlphaFold client whose behavior can be toggled for success / failure paths.
struct StubAlphaFoldClient: AlphaFoldDBProviding {
    var structureText: String = TestFixtures.sampleMMCIF()
    var failPrediction = false
    var failDownload = false
    var confidence: Double? = 91.5

    func prediction(for accession: String) async throws -> AlphaFoldPrediction {
        if failPrediction { throw AlphaFoldError.noPrediction(accession) }
        return AlphaFoldPrediction(
            uniprotAccession: accession,
            entryID: "AF-\(accession)-F1",
            gene: nil,
            organismScientificName: "Homo sapiens",
            latestVersion: 4,
            cifURL: URL(string: "https://alphafold.ebi.ac.uk/files/AF-\(accession)-F1-model_v4.cif"),
            bcifURL: nil,
            paeDocURL: nil,
            confidenceAverage: confidence,
            license: "CC BY 4.0"
        )
    }

    func downloadStructure(for prediction: AlphaFoldPrediction, format: StructureFormat) async throws -> URL {
        if failDownload { throw AlphaFoldError.missingStructureURL }
        let url = FileManager.default.temporaryDirectory.appending(path: "\(prediction.uniprotAccession)-\(UUID().uuidString).cif")
        try structureText.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

enum TestFixtures {
    /// Builds a small but valid mmCIF document with `residueCount` single-CA residues on chain A.
    static func sampleMMCIF(accession: String = "P0TEST", residueCount: Int = 40, chain: String = "A") -> String {
        var lines = [
            "data_\(accession)",
            "#",
            "loop_",
            "_atom_site.group_PDB",
            "_atom_site.id",
            "_atom_site.type_symbol",
            "_atom_site.label_atom_id",
            "_atom_site.label_comp_id",
            "_atom_site.label_asym_id",
            "_atom_site.label_seq_id",
            "_atom_site.Cartn_x",
            "_atom_site.Cartn_y",
            "_atom_site.Cartn_z",
            "_atom_site.B_iso_or_equiv"
        ]
        let confidences = [95.0, 85.0, 65.0, 45.0]
        for index in 0..<residueCount {
            let x = Double(index) * 3.8
            let b = confidences[index % confidences.count]
            lines.append("ATOM \(index + 1) C CA ALA \(chain) \(index + 1) \(x) 0.0 0.0 \(b)")
        }
        lines.append("#")
        return lines.joined(separator: "\n")
    }
}

enum TestSnapshot {
    /// Convenience factory for `HealthSnapshot` so individual tests only specify the fields they care about.
    static func make(
        isDemo: Bool = false,
        workouts: Int? = nil,
        types: [String] = [],
        activeEnergyKcal: Double? = nil,
        workoutHeartRate: Double? = nil,
        restingHeartRate: Double? = nil,
        sleepHours: Double? = nil,
        respiratoryRate: Double? = nil,
        oxygenSaturation: Double? = nil,
        vo2Max: Double? = nil
    ) -> HealthSnapshot {
        HealthSnapshot(
            generatedAt: .now,
            isDemo: isDemo,
            workoutsThisWeek: workouts,
            workoutTypesThisWeek: types,
            activeEnergyThisWeek: activeEnergyKcal.map { Measurement(value: $0, unit: .kilocalories) },
            averageWorkoutHeartRate: workoutHeartRate.map { Measurement(value: $0, unit: .beatsPerMinute) },
            restingHeartRate: restingHeartRate.map { Measurement(value: $0, unit: .beatsPerMinute) },
            averageSleepDuration: sleepHours.map { $0 * 3600 },
            respiratoryRate: respiratoryRate.map { Measurement(value: $0, unit: .respirationsPerMinute) },
            oxygenSaturation: oxygenSaturation,
            vo2Max: vo2Max
        )
    }
}

@MainActor
enum TestContainers {
    /// A single in-memory SwiftData container shared across the whole (serialized) suite.
    ///
    /// Creating a fresh `ModelContainer` per test is unsafe: a previous container's
    /// `NSPersistentStoreCoordinator` can be deallocated on its serial queue at the same
    /// moment the next test issues a fetch, deadlocking the test host indefinitely.
    /// Sharing one container removes that teardown race entirely.
    static let shared: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        // A failure here means the schema itself is broken — unrecoverable test setup.
        return try! ModelContainer(for: MolecularYouSchema.schema, configurations: configuration)
    }()

    /// The shared in-memory container with all persisted data cleared, so each test starts
    /// from an isolated, empty state without paying for a new container (and its teardown race).
    static func inMemory() throws -> ModelContainer {
        let context = shared.mainContext
        context.rollback() // discard any unsaved changes left by a prior test
        try context.delete(model: SavedProtein.self)
        try context.delete(model: SavedSystem.self)
        try context.delete(model: SavedModule.self)
        try context.delete(model: UserNote.self)
        try context.delete(model: RecentView.self)
        try context.delete(model: CachedStructureRecord.self)
        try context.delete(model: UserPreferences.self)
        try context.save()
        return shared
    }
}
