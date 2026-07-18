import Foundation
import SwiftData

@MainActor
protocol LibraryRepository: AnyObject {
    var savedProteinAccessions: Set<String> { get }
    var downloadedProteinAccessions: Set<String> { get }
    var notes: [UserNote] { get }
    func refresh()
    func isProteinSaved(_ accession: String) -> Bool
    func toggleProteinSaved(_ accession: String)
    func addRecent(itemID: String, itemType: String)
    func addNote(itemID: String, itemType: String, text: String)
    func deleteNote(_ note: UserNote)
    func recordCachedStructure(accession: String, url: URL, format: StructureFormat, bytes: Int)
    func clearCachedStructures() throws
    func storageSize() -> Int
}

@MainActor
@Observable
final class SwiftDataLibraryRepository: LibraryRepository {
    private let modelContext: ModelContext
    private(set) var savedProteinAccessions: Set<String> = []
    private(set) var downloadedProteinAccessions: Set<String> = []
    private(set) var notes: [UserNote] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }

    func refresh() {
        savedProteinAccessions = Set((try? modelContext.fetch(FetchDescriptor<SavedProtein>()).map(\.accession)) ?? [])
        downloadedProteinAccessions = Set((try? modelContext.fetch(FetchDescriptor<CachedStructureRecord>()).map(\.accession)) ?? [])
        notes = ((try? modelContext.fetch(FetchDescriptor<UserNote>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? [])
    }

    func isProteinSaved(_ accession: String) -> Bool {
        savedProteinAccessions.contains(accession)
    }

    func toggleProteinSaved(_ accession: String) {
        if savedProteinAccessions.contains(accession) {
            let descriptor = FetchDescriptor<SavedProtein>(predicate: #Predicate { $0.accession == accession })
            if let item = try? modelContext.fetch(descriptor).first {
                modelContext.delete(item)
            }
        } else {
            modelContext.insert(SavedProtein(accession: accession))
        }
        try? modelContext.save()
        refresh()
    }

    func addRecent(itemID: String, itemType: String) {
        let descriptor = FetchDescriptor<RecentView>(predicate: #Predicate { $0.itemID == itemID })
        if let item = try? modelContext.fetch(descriptor).first {
            item.viewedAt = .now
            item.itemType = itemType
        } else {
            modelContext.insert(RecentView(itemID: itemID, itemType: itemType))
        }
        try? modelContext.save()
    }

    func addNote(itemID: String, itemType: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(UserNote(itemID: itemID, itemType: itemType, text: trimmed))
        try? modelContext.save()
        refresh()
    }

    func deleteNote(_ note: UserNote) {
        modelContext.delete(note)
        try? modelContext.save()
        refresh()
    }

    func recordCachedStructure(accession: String, url: URL, format: StructureFormat, bytes: Int) {
        let descriptor = FetchDescriptor<CachedStructureRecord>(predicate: #Predicate { $0.accession == accession })
        if let record = try? modelContext.fetch(descriptor).first {
            record.localPath = url.path
            record.formatRawValue = format.rawValue
            record.bytes = bytes
            record.downloadedAt = .now
        } else {
            modelContext.insert(CachedStructureRecord(accession: accession, localPath: url.path, format: format, bytes: bytes))
        }
        try? modelContext.save()
        refresh()
    }

    func clearCachedStructures() throws {
        let records = try modelContext.fetch(FetchDescriptor<CachedStructureRecord>())
        for record in records {
            try? FileManager.default.removeItem(atPath: record.localPath)
            modelContext.delete(record)
        }
        try modelContext.save()
        refresh()
    }

    func storageSize() -> Int {
        ((try? modelContext.fetch(FetchDescriptor<CachedStructureRecord>()).map(\.bytes).reduce(0, +)) ?? 0)
    }
}

@MainActor
@Observable
final class InMemoryLibraryRepository: LibraryRepository {
    private(set) var savedProteinAccessions: Set<String> = []
    private(set) var downloadedProteinAccessions: Set<String> = []
    private(set) var notes: [UserNote] = []

    func refresh() {}
    func isProteinSaved(_ accession: String) -> Bool { savedProteinAccessions.contains(accession) }

    func toggleProteinSaved(_ accession: String) {
        if savedProteinAccessions.contains(accession) {
            savedProteinAccessions.remove(accession)
        } else {
            savedProteinAccessions.insert(accession)
        }
    }

    func addRecent(itemID: String, itemType: String) {}

    func addNote(itemID: String, itemType: String, text: String) {
        notes.insert(UserNote(itemID: itemID, itemType: itemType, text: text), at: 0)
    }

    func deleteNote(_ note: UserNote) {
        notes.removeAll { $0.id == note.id }
    }

    func recordCachedStructure(accession: String, url: URL, format: StructureFormat, bytes: Int) {
        downloadedProteinAccessions.insert(accession)
    }

    func clearCachedStructures() throws {
        downloadedProteinAccessions.removeAll()
    }

    func storageSize() -> Int { 0 }
}
