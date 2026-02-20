import Foundation
import SwiftData
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore
import os

/// Manages real-time Firestore snapshot listeners for followed lists.
///
/// Lifecycle:
/// - Activated when the user is signed in and has followed lists
/// - Attaches one listener per followed list document
/// - Updates local `FollowedList` + `FollowedListItem` records on change
/// - Detaches all listeners on sign-out or when the app backgrounds
///
/// Owned by `FlickSwiperApp` (or the Library tab), not by individual views.
/// Uses `@MainActor` because it writes to SwiftData which requires main thread.
@MainActor
@Observable
final class FollowedListSyncService {
    private let firestoreService = FirestoreService()
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "FollowedListSync")
    
    /// Active Firestore listeners keyed by published list doc ID.
    private var listeners: [String: ListenerRegistration] = [:]
    
    /// The ModelContext used for local persistence. Set once on activation.
    private var modelContext: ModelContext?
    
    /// Whether the service is currently active.
    private(set) var isActive = false
    
    // MARK: - Lifecycle
    
    /// Starts listening for changes to all followed lists.
    /// Call this when the user signs in or when the Library tab appears.
    func activate(context: ModelContext) {
        guard !isActive else { return }
        self.modelContext = context
        isActive = true
        
        logger.info("Activating followed list sync")
        attachListenersForAllFollowedLists()
    }
    
    /// Stops all listeners. Call on sign-out or app background.
    func deactivate() {
        guard isActive else { return }
        
        for (docID, listener) in listeners {
            listener.remove()
            logger.info("Detached listener for \(docID)")
        }
        listeners.removeAll()
        isActive = false
        
        logger.info("Deactivated followed list sync")
    }
    
    /// Attaches a listener for a single newly followed list.
    /// Called from SharedListView after a follow action.
    func attachListener(for docID: String) {
        guard isActive, listeners[docID] == nil else { return }
        startListening(to: docID)
    }
    
    /// Detaches the listener for an unfollowed list.
    /// Called from FollowedListDetailView after unfollow.
    func detachListener(for docID: String) {
        listeners[docID]?.remove()
        listeners.removeValue(forKey: docID)
        logger.info("Detached listener for \(docID)")
    }
    
    // MARK: - Internal
    
    private func attachListenersForAllFollowedLists() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<FollowedList>()
            let followedLists = try context.fetch(descriptor)
            
            for list in followedLists {
                startListening(to: list.firestoreDocID)
            }
            
            logger.info("Attached \(followedLists.count) listeners")
        } catch {
            logger.error("Failed to fetch followed lists: \(error.localizedDescription)")
        }
    }
    
    private func startListening(to docID: String) {
        guard listeners[docID] == nil else { return }
        
        let listener = firestoreService.addPublishedListListener(docID: docID) { [weak self] snapshot in
            // Callback fires on Firestore's background thread.
            // Dispatch to main for SwiftData writes.
            Task { @MainActor in
                self?.handleSnapshotUpdate(docID: docID, snapshot: snapshot)
            }
        }
        
        listeners[docID] = listener
        logger.info("Listening to \(docID)")
    }
    
    private func handleSnapshotUpdate(docID: String, snapshot: FirestoreService.PublishedListSnapshot?) {
        guard let context = modelContext else { return }
        
        // Find the local FollowedList record
        let id = docID
        let descriptor = FetchDescriptor<FollowedList>(
            predicate: #Predicate<FollowedList> { $0.firestoreDocID == id }
        )
        guard let localList = try? context.fetch(descriptor).first else {
            logger.warning("Received update for \(docID) but no local FollowedList found")
            return
        }
        
        guard let snapshot else {
            // Document was deleted or error occurred
            localList.isActive = false
            try? context.save()
            logger.info("List \(docID) marked inactive (snapshot nil)")
            return
        }
        
        // Update metadata
        localList.name = snapshot.name
        localList.ownerDisplayName = snapshot.ownerDisplayName
        localList.itemCount = snapshot.itemCount
        localList.isActive = snapshot.isActive
        localList.lastFetchedAt = Date()
        
        // Replace items: delete old, insert new
        let itemDescriptor = FetchDescriptor<FollowedListItem>(
            predicate: #Predicate<FollowedListItem> { $0.followedListID == id }
        )
        if let existingItems = try? context.fetch(itemDescriptor) {
            for item in existingItems {
                context.delete(item)
            }
        }
        
        for (index, item) in snapshot.items.enumerated() {
            let newItem = FollowedListItem(
                followedListID: docID,
                tmdbID: item.tmdbID,
                mediaType: item.mediaType,
                title: item.title,
                posterPath: item.posterPath,
                sortOrder: index
            )
            context.insert(newItem)
        }
        
        do {
            try context.save()
            logger.info("Updated local cache for \(docID): \(snapshot.items.count) items")
        } catch {
            logger.error("Failed to save snapshot update for \(docID): \(error.localizedDescription)")
        }
    }
}
