import SwiftData
import Foundation

// MARK: - Schema V1 (Initial Launch)

/// V1: Original schema — only SwipedItem, no ratings, no lists.
///
/// Each VersionedSchema must define its own model types that **exactly match**
/// the on-disk schema at that version. Referencing the current (evolved) model
/// types would produce the wrong hash, causing "unknown model version" errors.
///
/// Nested classes use the SAME names as the originals (SwipedItem, not SwipedItemV1)
/// because SwiftData maps entity names from the class name. Swift's enum namespacing
/// prevents collisions: `FlickSwiperSchemaV1.SwipedItem` ≠ `FlickSwiperSchemaV2.SwipedItem`.
enum FlickSwiperSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [SwipedItem.self]
    }
    
    @Model
    final class SwipedItem {
        @Attribute(.unique) var uniqueID: String
        var mediaID: Int
        var mediaType: String
        var swipeDirection: String
        var dateSwiped: Date
        var title: String = ""
        var overview: String = ""
        var posterPath: String?
        var releaseDate: String?
        var rating: Double?
        
        init(uniqueID: String = "", mediaID: Int = 0, mediaType: String = "",
             swipeDirection: String = "", dateSwiped: Date = .now) {
            self.uniqueID = uniqueID
            self.mediaID = mediaID
            self.mediaType = mediaType
            self.swipeDirection = swipeDirection
            self.dateSwiped = dateSwiped
        }
    }
}

// MARK: - Schema V2 (Ratings + Custom Lists)

/// V2: Added personalRating, genreIDsString, sourcePlatform to SwipedItem.
///     Added UserList and ListEntry models for custom lists.
enum FlickSwiperSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [SwipedItem.self, UserList.self, ListEntry.self]
    }
    
    @Model
    final class SwipedItem {
        @Attribute(.unique) var uniqueID: String
        var mediaID: Int
        var mediaType: String
        var swipeDirection: String
        var dateSwiped: Date
        var title: String = ""
        var overview: String = ""
        var posterPath: String?
        var releaseDate: String?
        var rating: Double?
        // V2 additions
        var personalRating: Int?
        var genreIDsString: String?
        var sourcePlatform: String?
        
        init(uniqueID: String = "", mediaID: Int = 0, mediaType: String = "",
             swipeDirection: String = "", dateSwiped: Date = .now) {
            self.uniqueID = uniqueID
            self.mediaID = mediaID
            self.mediaType = mediaType
            self.swipeDirection = swipeDirection
            self.dateSwiped = dateSwiped
        }
    }
    
    @Model
    final class UserList {
        var id: UUID
        var name: String
        var createdDate: Date
        var sortOrder: Int
        
        init(id: UUID = UUID(), name: String = "", createdDate: Date = .now, sortOrder: Int = 0) {
            self.id = id
            self.name = name
            self.createdDate = createdDate
            self.sortOrder = sortOrder
        }
    }
    
    @Model
    final class ListEntry {
        var id: UUID
        var listID: UUID
        var itemID: String
        var dateAdded: Date
        var sortOrder: Int
        
        init(id: UUID = UUID(), listID: UUID = UUID(), itemID: String = "",
             dateAdded: Date = .now, sortOrder: Int = 0) {
            self.id = id
            self.listID = listID
            self.itemID = itemID
            self.dateAdded = dateAdded
            self.sortOrder = sortOrder
        }
    }
}

// MARK: - Schema V3 (Social Lists — Current)

/// V3: Added social list fields to UserList (firestoreDocID, isPublished, lastSyncedAt).
///     Added FollowedList and FollowedListItem models.
///
/// As the **current** schema version, V3 references the top-level model types
/// that the rest of the app actually uses. Only older versions need frozen copies.
enum FlickSwiperSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [SwipedItem.self, UserList.self, ListEntry.self,
         FollowedList.self, FollowedListItem.self]
    }
}

// MARK: - Migration Plan

/// Staged migration plan for handling schema changes across app updates.
///
/// All stages are lightweight because every change has been additive optional
/// properties or new models — no renames, type changes, or required fields.
enum FlickSwiperMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FlickSwiperSchemaV1.self, FlickSwiperSchemaV2.self, FlickSwiperSchemaV3.self]
    }
    
    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }
    
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: FlickSwiperSchemaV1.self,
        toVersion: FlickSwiperSchemaV2.self
    )
    
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: FlickSwiperSchemaV2.self,
        toVersion: FlickSwiperSchemaV3.self
    )
}
