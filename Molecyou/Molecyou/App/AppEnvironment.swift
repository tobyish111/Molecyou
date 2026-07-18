import Foundation
import SwiftData

@MainActor
@Observable
final class AppEnvironment {
    let knowledgeGraph: KnowledgeGraphStore
    let healthProvider: any HealthDataProviding
    let contextEngine: any HealthContextEvaluating
    let alphaFoldClient: any AlphaFoldDBProviding
    let structureCache: StructureCache
    let libraryRepository: LibraryRepository
    let analytics: any AnalyticsTracking

    init(
        knowledgeGraph: KnowledgeGraphStore,
        healthProvider: any HealthDataProviding,
        contextEngine: any HealthContextEvaluating,
        alphaFoldClient: any AlphaFoldDBProviding,
        structureCache: StructureCache,
        libraryRepository: LibraryRepository,
        analytics: any AnalyticsTracking
    ) {
        self.knowledgeGraph = knowledgeGraph
        self.healthProvider = healthProvider
        self.contextEngine = contextEngine
        self.alphaFoldClient = alphaFoldClient
        self.structureCache = structureCache
        self.libraryRepository = libraryRepository
        self.analytics = analytics
    }

    static func live(modelContext: ModelContext) -> AppEnvironment {
        let graph = KnowledgeGraphStore.loadBundled()
        let cache = StructureCache()
        return AppEnvironment(
            knowledgeGraph: graph,
            healthProvider: HealthKitManager(),
            contextEngine: DefaultHealthContextEngine(),
            alphaFoldClient: AlphaFoldDBClient(structureCache: cache),
            structureCache: cache,
            libraryRepository: SwiftDataLibraryRepository(modelContext: modelContext),
            analytics: NoOpAnalyticsTracker()
        )
    }

    static let preview = AppEnvironment(
        knowledgeGraph: .preview,
        healthProvider: DemoHealthDataProvider(),
        contextEngine: DefaultHealthContextEngine(),
        alphaFoldClient: PreviewAlphaFoldDBClient(),
        structureCache: StructureCache(),
        libraryRepository: InMemoryLibraryRepository(),
        analytics: NoOpAnalyticsTracker()
    )
}
