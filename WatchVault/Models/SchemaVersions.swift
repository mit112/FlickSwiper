import SwiftData

// MARK: - Schema Versioning

/// V1: Initial schema at launch
enum WatchVaultSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [SwipedItem.self]
    }
}

/// V2: Added personalRating, genreIDsString, sourcePlatform to SwipedItem;
///     Added UserList and ListEntry models for custom lists
enum WatchVaultSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [SwipedItem.self, UserList.self, ListEntry.self]
    }
}

// MARK: - Migration Plan

/// Migration plan for handling schema changes across app updates
enum WatchVaultMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WatchVaultSchemaV1.self, WatchVaultSchemaV2.self]
    }
    
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: WatchVaultSchemaV1.self,
                      toVersion: WatchVaultSchemaV2.self)]
    }
}
