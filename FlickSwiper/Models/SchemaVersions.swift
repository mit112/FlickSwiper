import SwiftData

// MARK: - Schema Versioning

/// V1: Initial schema at launch
enum FlickSwiperSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [SwipedItem.self]
    }
}

/// V2: Added personalRating, genreIDsString, sourcePlatform to SwipedItem;
///     Added UserList and ListEntry models for custom lists
enum FlickSwiperSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [SwipedItem.self, UserList.self, ListEntry.self]
    }
}

// MARK: - Migration Plan

/// Migration plan for handling schema changes across app updates
enum FlickSwiperMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FlickSwiperSchemaV1.self, FlickSwiperSchemaV2.self]
    }
    
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: FlickSwiperSchemaV1.self,
                      toVersion: FlickSwiperSchemaV2.self)]
    }
}
