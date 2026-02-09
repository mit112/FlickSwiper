import SwiftData

// MARK: - Schema Versioning

/// V1: Initial schema at launch
enum AlreadySeenSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [SwipedItem.self]
    }
}

/// V2: Added personalRating, genreIDsString, sourcePlatform to SwipedItem;
///     Added UserList and ListEntry models for custom lists
enum AlreadySeenSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [SwipedItem.self, UserList.self, ListEntry.self]
    }
}

// MARK: - Migration Plan

/// Migration plan for handling schema changes across app updates
enum AlreadySeenMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AlreadySeenSchemaV1.self, AlreadySeenSchemaV2.self]
    }
    
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: AlreadySeenSchemaV1.self,
                      toVersion: AlreadySeenSchemaV2.self)]
    }
}
