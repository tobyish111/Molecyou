import Foundation
import SwiftData

@Model
final class SavedProtein {
    @Attribute(.unique) var accession: String
    var savedAt: Date

    init(accession: String, savedAt: Date = .now) {
        self.accession = accession
        self.savedAt = savedAt
    }
}

@Model
final class SavedSystem {
    @Attribute(.unique) var systemID: String
    var savedAt: Date

    init(systemID: String, savedAt: Date = .now) {
        self.systemID = systemID
        self.savedAt = savedAt
    }
}

@Model
final class SavedModule {
    @Attribute(.unique) var moduleID: String
    var savedAt: Date

    init(moduleID: String, savedAt: Date = .now) {
        self.moduleID = moduleID
        self.savedAt = savedAt
    }
}

@Model
final class UserNote {
    var id: UUID
    var itemID: String
    var itemType: String
    var text: String
    var updatedAt: Date

    init(id: UUID = UUID(), itemID: String, itemType: String, text: String, updatedAt: Date = .now) {
        self.id = id
        self.itemID = itemID
        self.itemType = itemType
        self.text = text
        self.updatedAt = updatedAt
    }
}

@Model
final class RecentView {
    @Attribute(.unique) var itemID: String
    var itemType: String
    var viewedAt: Date

    init(itemID: String, itemType: String, viewedAt: Date = .now) {
        self.itemID = itemID
        self.itemType = itemType
        self.viewedAt = viewedAt
    }
}

@Model
final class CachedStructureRecord {
    @Attribute(.unique) var accession: String
    var localPath: String
    var formatRawValue: String
    var bytes: Int
    var downloadedAt: Date
    var etag: String?
    var lastModified: String?

    init(accession: String, localPath: String, format: StructureFormat, bytes: Int, downloadedAt: Date = .now, etag: String? = nil, lastModified: String? = nil) {
        self.accession = accession
        self.localPath = localPath
        self.formatRawValue = format.rawValue
        self.bytes = bytes
        self.downloadedAt = downloadedAt
        self.etag = etag
        self.lastModified = lastModified
    }
}

@Model
final class UserPreferences {
    @Attribute(.unique) var id: String
    var displayName: String
    var selectedInterestRawValues: [String]
    var demonstrationMode: Bool
    var appearanceRawValue: String

    init(id: String = "current", displayName: String = "Toby", selectedInterests: Set<UserInterest> = Set(UserInterest.allCases), demonstrationMode: Bool = true, appearance: String = "system") {
        self.id = id
        self.displayName = displayName
        self.selectedInterestRawValues = selectedInterests.map(\.rawValue)
        self.demonstrationMode = demonstrationMode
        self.appearanceRawValue = appearance
    }

    var selectedInterests: Set<UserInterest> {
        get { Set(selectedInterestRawValues.compactMap(UserInterest.init(rawValue:))) }
        set { selectedInterestRawValues = newValue.map(\.rawValue) }
    }
}

enum MolecularYouSchema {
    static let schema = Schema([
        SavedProtein.self,
        SavedSystem.self,
        SavedModule.self,
        UserNote.self,
        RecentView.self,
        CachedStructureRecord.self,
        UserPreferences.self
    ])
}
