import Foundation
import SwiftData
import os

/// Coordinates publishing, unpublishing, and syncing local UserLists with Firestore.
///
/// This is a lightweight coordinator — not a persistent service. It's created
/// on-demand with a ModelContext and AuthService reference, used for one operation,
/// then discarded. Keeps view code clean while centralizing publish logic.
@MainActor
struct ListPublisher {
    private let context: ModelContext
    private let firestoreService = FirestoreService()
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "ListPublisher")
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Publish
    
    /// Publishes a local UserList to Firestore.
    /// Returns the generated share link URL.
    ///
    /// - Parameters:
    ///   - list: The local UserList to publish
    ///   - ownerUID: Firebase Auth UID of the current user
    ///   - ownerDisplayName: Display name to show on the published list
    /// - Returns: Universal Link URL for sharing
    func publish(
        list: UserList,
        ownerUID: String,
        ownerDisplayName: String
    ) async throws -> URL {
        // 1. Fetch list entries and resolve items
        let listID = list.id
        let entriesDescriptor = FetchDescriptor<ListEntry>(
            predicate: #Predicate<ListEntry> { $0.listID == listID }
        )
        let entries = try context.fetch(entriesDescriptor)
            .sorted { $0.sortOrder < $1.sortOrder }
        
        // 2. Resolve SwipedItems for each entry
        let itemIDs = entries.map(\.itemID)
        let allItemsDescriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate<SwipedItem> {
                $0.swipeDirection == "seen" || $0.swipeDirection == "watchlist"
            }
        )
        let allItems = try context.fetch(allItemsDescriptor)
        let itemMap = Dictionary(uniqueKeysWithValues: allItems.map { ($0.uniqueID, $0) })
        
        // 3. Serialize to Firestore format
        let publishedItems: [FirestoreService.PublishedListItem] = itemIDs.compactMap { id in
            guard let item = itemMap[id] else { return nil }
            return FirestoreService.PublishedListItem(
                tmdbID: item.mediaID,
                mediaType: item.mediaType,
                title: item.title,
                posterPath: item.posterPath,
                dateAdded: item.dateSwiped
            )
        }
        
        let data = FirestoreService.PublishedListData(
            ownerUID: ownerUID,
            ownerDisplayName: ownerDisplayName,
            name: list.name,
            items: publishedItems
        )
        
        // 4. Write to Firestore
        let docID = try await firestoreService.publishList(data)
        
        // 5. Update local UserList
        list.firestoreDocID = docID
        list.isPublished = true
        list.lastSyncedAt = Date()
        try context.save()
        
        // 6. Generate share link
        guard let url = await firestoreService.shareLink(for: docID) else {
            throw PublishError.linkGenerationFailed
        }
        
        logger.info("Published '\(list.name)' → \(url.absoluteString)")
        return url
    }
    
    // MARK: - Unpublish
    
    /// Unpublishes a list: sets isActive=false in Firestore, clears local publish state.
    /// Per decision Q6: unpublishing generates a new doc ID on re-publish.
    func unpublish(list: UserList) async throws {
        guard let docID = list.firestoreDocID else {
            logger.warning("Attempted to unpublish a list that isn't published")
            return
        }
        
        // 1. Soft-delete in Firestore
        try await firestoreService.unpublishList(docID: docID)
        
        // 2. Clear local publish state
        list.firestoreDocID = nil
        list.isPublished = false
        list.lastSyncedAt = nil
        try context.save()
        
        logger.info("Unpublished '\(list.name)' (was doc \(docID))")
    }
    
    // MARK: - Sync Changes
    
    /// Pushes local list changes (items, name) to the existing Firestore document.
    /// Call this after adding/removing items or renaming a published list.
    func syncIfPublished(list: UserList) async throws {
        guard list.isPublished, let docID = list.firestoreDocID else {
            return // Not published, nothing to sync
        }
        
        // Re-fetch entries and items (same logic as publish)
        let listID = list.id
        let entriesDescriptor = FetchDescriptor<ListEntry>(
            predicate: #Predicate<ListEntry> { $0.listID == listID }
        )
        let entries = try context.fetch(entriesDescriptor)
            .sorted { $0.sortOrder < $1.sortOrder }
        
        let itemIDs = entries.map(\.itemID)
        let allItemsDescriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate<SwipedItem> {
                $0.swipeDirection == "seen" || $0.swipeDirection == "watchlist"
            }
        )
        let allItems = try context.fetch(allItemsDescriptor)
        let itemMap = Dictionary(uniqueKeysWithValues: allItems.map { ($0.uniqueID, $0) })
        
        let publishedItems: [FirestoreService.PublishedListItem] = itemIDs.compactMap { id in
            guard let item = itemMap[id] else { return nil }
            return FirestoreService.PublishedListItem(
                tmdbID: item.mediaID,
                mediaType: item.mediaType,
                title: item.title,
                posterPath: item.posterPath,
                dateAdded: item.dateSwiped
            )
        }
        
        try await firestoreService.updatePublishedList(
            docID: docID,
            name: list.name,
            items: publishedItems
        )
        
        list.lastSyncedAt = Date()
        try context.save()
        
        logger.info("Synced '\(list.name)' to Firestore")
    }
    
    // MARK: - Errors
    
    enum PublishError: LocalizedError {
        case linkGenerationFailed
        
        var errorDescription: String? {
            switch self {
            case .linkGenerationFailed:
                return "Failed to generate a share link. Please try again."
            }
        }
    }
}
