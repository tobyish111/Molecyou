import Foundation
import SwiftData
import XCTest
@testable import Molecyou

/// Coverage for saving, notes, recents, and cached-structure persistence via SwiftData.
///
/// Uses XCTest rather than swift-testing: SwiftData `ModelContainer`/`@Model` work reliably under
/// XCTest's synchronous main-thread harness, whereas the swift-testing async `@MainActor` harness
/// can deadlock the test host when creating in-memory containers.
@MainActor
final class PersistenceTests: XCTestCase {
    private func makeRepository() throws -> (SwiftDataLibraryRepository, ModelContainer) {
        let container = try TestContainers.inMemory()
        return (SwiftDataLibraryRepository(modelContext: container.mainContext), container)
    }

    func testSaveTogglePersistsAndIsUnique() throws {
        let (repo, container) = try makeRepository()
        XCTAssertFalse(repo.isProteinSaved("P69905"))
        repo.toggleProteinSaved("P69905")
        XCTAssertTrue(repo.isProteinSaved("P69905"))
        repo.toggleProteinSaved("P69905")
        XCTAssertFalse(repo.isProteinSaved("P69905"))

        repo.toggleProteinSaved("P68871")
        let reopened = SwiftDataLibraryRepository(modelContext: container.mainContext)
        XCTAssertTrue(reopened.savedProteinAccessions.contains("P68871"))
    }

    func testNotesAddDeleteAndOrderByMostRecent() throws {
        let (repo, _) = try makeRepository()
        repo.addNote(itemID: "P69905", itemType: "protein", text: "First note")
        repo.addNote(itemID: "general", itemType: "note", text: "Second note")
        XCTAssertEqual(repo.notes.count, 2)
        XCTAssertEqual(repo.notes.first?.text, "Second note")

        let toDelete = try XCTUnwrap(repo.notes.first { $0.text == "First note" })
        repo.deleteNote(toDelete)
        XCTAssertEqual(repo.notes.count, 1)
        XCTAssertTrue(repo.notes.allSatisfy { $0.text != "First note" })
    }

    func testBlankNotesAreIgnored() throws {
        let (repo, _) = try makeRepository()
        repo.addNote(itemID: "x", itemType: "note", text: "   \n  ")
        XCTAssertTrue(repo.notes.isEmpty)
    }

    func testRecentViewUpsertsInsteadOfDuplicating() throws {
        let (repo, container) = try makeRepository()
        repo.addRecent(itemID: "P69905", itemType: "protein")
        repo.addRecent(itemID: "P69905", itemType: "protein")
        let recents = try container.mainContext.fetch(FetchDescriptor<RecentView>())
        XCTAssertEqual(recents.filter { $0.itemID == "P69905" }.count, 1)
    }

    func testCachedStructureRecordsAndStorageSize() throws {
        let (repo, _) = try makeRepository()
        repo.recordCachedStructure(accession: "P69905", url: URL(filePath: "/tmp/P69905.cif"), format: .mmcif, bytes: 2048)
        repo.recordCachedStructure(accession: "P68871", url: URL(filePath: "/tmp/P68871.cif"), format: .bcif, bytes: 1024)
        XCTAssertEqual(repo.downloadedProteinAccessions, ["P69905", "P68871"])
        XCTAssertEqual(repo.storageSize(), 3072)

        repo.recordCachedStructure(accession: "P69905", url: URL(filePath: "/tmp/P69905-v2.cif"), format: .mmcif, bytes: 4096)
        XCTAssertEqual(repo.downloadedProteinAccessions.count, 2)
        XCTAssertEqual(repo.storageSize(), 5120)
    }

    func testClearCachedStructuresRemovesRecordsButKeepsSaves() throws {
        let (repo, _) = try makeRepository()
        repo.toggleProteinSaved("P69905")
        repo.recordCachedStructure(accession: "P69905", url: URL(filePath: "/tmp/P69905.cif"), format: .mmcif, bytes: 2048)
        XCTAssertFalse(repo.downloadedProteinAccessions.isEmpty)

        try repo.clearCachedStructures()
        XCTAssertTrue(repo.downloadedProteinAccessions.isEmpty)
        XCTAssertEqual(repo.storageSize(), 0)
        XCTAssertTrue(repo.isProteinSaved("P69905"))
    }

    func testInMemoryRepositoryMatchesProtocolBehavior() {
        let repo = InMemoryLibraryRepository()
        repo.toggleProteinSaved("P68871")
        XCTAssertTrue(repo.isProteinSaved("P68871"))
        repo.addNote(itemID: "P68871", itemType: "protein", text: "note")
        XCTAssertEqual(repo.notes.count, 1)
        repo.deleteNote(repo.notes[0])
        XCTAssertTrue(repo.notes.isEmpty)
        repo.recordCachedStructure(accession: "P68871", url: URL(filePath: "/tmp/x.cif"), format: .mmcif, bytes: 10)
        XCTAssertTrue(repo.downloadedProteinAccessions.contains("P68871"))
        try? repo.clearCachedStructures()
        XCTAssertTrue(repo.downloadedProteinAccessions.isEmpty)
    }

    func testUserPreferencesRoundTripInterests() {
        let prefs = UserPreferences()
        XCTAssertEqual(prefs.selectedInterests, Set(UserInterest.allCases))
        prefs.selectedInterests = [.sleep, .metabolism]
        XCTAssertEqual(prefs.selectedInterests, [.sleep, .metabolism])
        XCTAssertEqual(Set(prefs.selectedInterestRawValues), Set(["Sleep and circadian rhythm", "Metabolism"]))
    }

    func testUserPreferencesDefaults() {
        let prefs = UserPreferences()
        XCTAssertEqual(prefs.id, "current")
        XCTAssertEqual(prefs.displayName, "Toby")
        XCTAssertTrue(prefs.demonstrationMode)
        XCTAssertEqual(prefs.appearanceRawValue, "system")
    }
}
