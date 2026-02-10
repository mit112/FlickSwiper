import SwiftData

// MARK: - Schema Versioning

/// V1: Initial schema at launch
enum SeenItSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [SwipedItem.self]
    }
}

/// V2: Added personalRating, genreIDsString, sourcePlatform to SwipedItem;
///     Added UserList and ListEntry models for custom lists
enum SeenItSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [SwipedItem.self, UserList.self, ListEntry.self]
    }
}

// MARK: - Migration Plan

/// Migration plan for handling schema changes across app updates
enum SeenItMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SeenItSchemaV1.self, SeenItSchemaV2.self]
    }
    
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SeenItSchemaV1.self,
                      toVersion: SeenItSchemaV2.self)]
    }
}
