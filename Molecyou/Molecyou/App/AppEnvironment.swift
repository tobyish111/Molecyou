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

    /// Bumped whenever the health snapshot should be re-read — e.g. HealthKit access was just
    /// granted, or the app returned to the foreground (access may have been changed in Settings).
    /// Health-driven views observe this via `.task(id:)` and reload when it changes.
    private(set) var healthRefreshID = 0

    /// Marks the current health snapshot as stale so observing views reload it.
    func invalidateHealthData() {
        healthRefreshID &+= 1
    }

    /// Requests HealthKit authorization, then invalidates cached health data so any
    /// newly-authorized workouts and metrics link across the app immediately.
    func requestHealthAuthorization() async -> HealthAuthorizationState {
        let state = await healthProvider.requestAuthorization()
        invalidateHealthData()
        return state
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
