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

    static func live(modelContext: ModelContext, demonstrationMode: Bool) -> AppEnvironment {
        let graph = KnowledgeGraphStore.loadBundled()
        let cache = StructureCache()
        let arguments = Set(ProcessInfo.processInfo.arguments)
        let healthProvider: any HealthDataProviding
        let alphaFoldClient: any AlphaFoldDBProviding

        if arguments.contains("UITestLinkedHealthData") {
            healthProvider = LinkedHealthDataPreviewProvider()
        } else if arguments.contains("UITestNoHealthData") {
            healthProvider = EmptyHealthDataProvider()
        } else if demonstrationMode {
            healthProvider = DemoHealthDataProvider()
        } else {
            healthProvider = HealthKitManager()
        }

        if arguments.contains("UITestPreviewAlphaFold") {
            alphaFoldClient = PreviewAlphaFoldDBClient()
        } else {
            alphaFoldClient = AlphaFoldDBClient(structureCache: cache)
        }

        return AppEnvironment(
            knowledgeGraph: graph,
            healthProvider: healthProvider,
            contextEngine: DefaultHealthContextEngine(),
            alphaFoldClient: alphaFoldClient,
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
