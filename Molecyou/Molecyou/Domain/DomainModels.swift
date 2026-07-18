import Foundation
import SwiftUI

enum UserInterest: String, CaseIterable, Identifiable, Codable, Sendable {
    case cardiovascular = "Cardiovascular biology"
    case exercise = "Exercise and muscle"
    case sleep = "Sleep and circadian rhythm"
    case metabolism = "Metabolism"
    case respiratory = "Respiratory biology"
    case nervous = "Nervous system"
    case immune = "Immune system"
    case general = "General molecular biology"

    var id: String { rawValue }
}

enum RelevanceLevel: String, Codable, Sendable, CaseIterable {
    case high = "High"
    case moderate = "Moderate"
    case general = "General interest"
}

enum BiologicalSystemKind: String, Codable, Sendable, CaseIterable {
    case cardiovascular, respiratory, musculoskeletal, nervous, endocrine, immune, digestive, renal, metabolic, circadian
}

struct BiologicalSystem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let kind: BiologicalSystemKind
    let name: String
    let shortDescription: String
    let overview: String
    let whyItMatters: String
    let icon: String
    let accentColors: [String]
    let pathways: [String]
    let proteinAccessions: [String]
    let moduleIDs: [String]
}

struct Pathway: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let systemID: String
    let name: String
    let summary: String
    let proteinAccessions: [String]
}

struct Protein: Identifiable, Codable, Hashable, Sendable {
    var id: String { uniprotAccession }
    let name: String
    let geneSymbol: String
    let uniprotAccession: String
    let organism: String
    let functionSummary: String
    let cellularLocation: String
    let systems: [String]
    let molecularFunction: String
    let proteinType: String
    let alphaFoldAvailable: Bool
    let healthContextSummary: String
    let sourceIDs: [String]
}

struct EducationModule: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let systemID: String
    let title: String
    let summary: String
    let steps: [EducationStep]
    let sourceIDs: [String]
}

struct EducationStep: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let body: String
    let symbol: String
}

struct SourceReference: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let publisher: String
    let url: URL?
    let license: String?
    let reviewedDate: String
}

struct KnowledgeGraph: Codable, Sendable {
    let systems: [BiologicalSystem]
    let pathways: [Pathway]
    let proteins: [Protein]
    let modules: [EducationModule]
    let sources: [SourceReference]
}

struct HealthSnapshot: Sendable, Equatable {
    let generatedAt: Date
    let isDemo: Bool
    let workoutsThisWeek: Int?
    let activeEnergyThisWeek: Measurement<UnitEnergy>?
    let averageWorkoutHeartRate: Measurement<UnitFrequency>?
    let restingHeartRate: Measurement<UnitFrequency>?
    let averageSleepDuration: TimeInterval?
    let respiratoryRate: Measurement<UnitFrequency>?
    let oxygenSaturation: Double?
    let vo2Max: Double?
}

struct HealthContextRecommendation: Identifiable, Hashable, Sendable {
    var id: String { systemID }
    let systemID: String
    let relevance: RelevanceLevel
    let reasons: [String]
}

enum HealthAuthorizationState: Equatable, Sendable {
    case unavailable
    case notRequested
    case requested
    case available
    case failed(String)
}

enum StructureFormat: String, CaseIterable, Codable, Sendable {
    case mmcif = "mmCIF"
    case bcif = "BCIF"
}

struct AlphaFoldPrediction: Identifiable, Codable, Hashable, Sendable {
    var id: String { uniprotAccession }
    let uniprotAccession: String
    let entryID: String
    let gene: String?
    let organismScientificName: String?
    let latestVersion: Int?
    let cifURL: URL?
    let bcifURL: URL?
    let paeDocURL: URL?
    let confidenceAverage: Double?
    let license: String
}

enum RepresentationType: String, CaseIterable, Codable, Sendable, Identifiable {
    case ribbon = "Ribbon"
    case surface = "Surface"
    case ballAndStick = "Ball + stick"
    case atoms = "Atoms"
    var id: String { rawValue }
}

enum ColorMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case chain = "Chain"
    case element = "Element"
    case confidence = "Confidence"
    case uniform = "Uniform"
    var id: String { rawValue }
}

enum MolecularViewerCommand: Codable, Sendable, Equatable {
    case resetCamera
    case centerStructure
    case setRepresentation(RepresentationType)
    case setColorMode(ColorMode)
    case focusResidue(chainID: String, sequenceNumber: Int)
    case toggleLabels(Bool)
}

struct SearchFilters: Equatable, Sendable {
    var systemID: String?
    var molecularFunction: String?
    var proteinType: String?
    var savedOnly = false
    var downloadedOnly = false
}

enum AppRoute: Hashable, Sendable {
    case system(String)
    case protein(String)
    case functionModule(String)
    case viewer(String)
    case healthContext(String)
}
