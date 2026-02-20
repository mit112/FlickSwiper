import Foundation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore
import os

/// Handles all Firestore read/write operations for the social lists feature.
///
/// Thread-safe via actor isolation. All methods require the caller to provide
/// necessary IDs rather than reaching into Auth state directly, making the
/// service testable with dependency injection.
actor FirestoreService {
    /// Computed property — `Firestore.firestore()` returns a singleton so this is cheap.
    /// Avoids initialization before `FirebaseApp.configure()` is called.
    /// `nonisolated` because Firestore is internally thread-safe.
    nonisolated private var db: Firestore { Firestore.firestore() }
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "Firestore")
    
    // MARK: - Publish a List
    
    /// Represents a single item in a published list's `items` array.
    struct PublishedListItem: Codable {
        let tmdbID: Int
        let mediaType: String       // "movie" or "tvShow"
        let title: String
        let posterPath: String?
        let dateAdded: Date
    }
    
    /// Data structure for a published list document.
    struct PublishedListData {
        let ownerUID: String
        let ownerDisplayName: String
        let name: String
        let items: [PublishedListItem]
    }
    
    /// Snapshot of a published list fetched from Firestore.
    struct PublishedListSnapshot {
        let docID: String
        let ownerUID: String
        let ownerDisplayName: String
        let name: String
        let description: String
        let items: [PublishedListItem]
        let itemCount: Int
        let isActive: Bool
        let createdAt: Date?
        let updatedAt: Date?
    }
    
    /// Creates a new published list document in Firestore.
    /// Returns the Firestore document ID for link generation.
    func publishList(_ data: PublishedListData) async throws -> String {
        let itemDicts: [[String: Any]] = data.items.map { item in
            var dict: [String: Any] = [
                "tmdbID": item.tmdbID,
                "mediaType": item.mediaType,
                "title": item.title,
                "dateAdded": Timestamp(date: item.dateAdded)
            ]
            if let posterPath = item.posterPath {
                dict["posterPath"] = posterPath
            }
            return dict
        }
        
        let docData: [String: Any] = [
            "ownerUID": data.ownerUID,
            "ownerDisplayName": data.ownerDisplayName,
            "name": data.name,
            "description": "",
            "items": itemDicts,
            "itemCount": data.items.count,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "isActive": true
        ]
        
        let docRef = try await db.collection(Constants.Firestore.publishedListsCollection)
            .addDocument(data: docData)
        
        logger.info("Published list '\(data.name)' with doc ID: \(docRef.documentID)")
        return docRef.documentID
    }
    
    // MARK: - Update a Published List
    
    /// Pushes local list changes (items, name) to the existing Firestore document.
    func updatePublishedList(docID: String, name: String, items: [PublishedListItem]) async throws {
        let itemDicts: [[String: Any]] = items.map { item in
            var dict: [String: Any] = [
                "tmdbID": item.tmdbID,
                "mediaType": item.mediaType,
                "title": item.title,
                "dateAdded": Timestamp(date: item.dateAdded)
            ]
            if let posterPath = item.posterPath {
                dict["posterPath"] = posterPath
            }
            return dict
        }
        
        try await db.collection(Constants.Firestore.publishedListsCollection).document(docID).updateData([
            "name": name,
            "items": itemDicts,
            "itemCount": items.count,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        logger.info("Updated published list \(docID)")
    }
    
    // MARK: - Unpublish
    
    /// Soft-deletes a published list. Followers will see "no longer available."
    func unpublishList(docID: String) async throws {
        try await db.collection(Constants.Firestore.publishedListsCollection).document(docID).updateData([
            "isActive": false,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        logger.info("Unpublished list \(docID)")
    }
    
    // MARK: - Fetch a Published List
    
    /// Fetches a single published list by Firestore document ID.
    /// Used when handling a deep link.
    func fetchPublishedList(docID: String) async throws -> PublishedListSnapshot? {
        let doc = try await db.collection(Constants.Firestore.publishedListsCollection)
            .document(docID)
            .getDocument()
        
        guard doc.exists, let data = doc.data() else {
            return nil
        }
        
        return parsePublishedListSnapshot(docID: doc.documentID, data: data)
    }
    
    // MARK: - Follow / Unfollow
    
    /// Creates a follow relationship between the current user and a published list.
    /// Returns the follow document ID.
    func followList(followerUID: String, listID: String) async throws -> String {
        // Check for existing follow to prevent duplicates
        let existing = try await db.collection(Constants.Firestore.followsCollection)
            .whereField("followerUID", isEqualTo: followerUID)
            .whereField("listID", isEqualTo: listID)
            .getDocuments()
        
        if let existingDoc = existing.documents.first {
            logger.info("Already following list \(listID)")
            return existingDoc.documentID
        }
        
        let docRef = try await db.collection(Constants.Firestore.followsCollection)
            .addDocument(data: [
                "followerUID": followerUID,
                "listID": listID,
                "followedAt": FieldValue.serverTimestamp()
            ])
        
        logger.info("Followed list \(listID), follow doc: \(docRef.documentID)")
        return docRef.documentID
    }
    
    /// Removes the follow relationship.
    func unfollowList(followerUID: String, listID: String) async throws {
        let snapshot = try await db.collection(Constants.Firestore.followsCollection)
            .whereField("followerUID", isEqualTo: followerUID)
            .whereField("listID", isEqualTo: listID)
            .getDocuments()
        
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
        
        logger.info("Unfollowed list \(listID)")
    }
    
    /// Checks if the given user is following a specific list.
    func isFollowing(followerUID: String, listID: String) async throws -> Bool {
        let snapshot = try await db.collection(Constants.Firestore.followsCollection)
            .whereField("followerUID", isEqualTo: followerUID)
            .whereField("listID", isEqualTo: listID)
            .limit(to: 1)
            .getDocuments()
        
        return !snapshot.documents.isEmpty
    }
    
    /// Fetches all list IDs that a user is following.
    func fetchFollowedListIDs(followerUID: String) async throws -> [String] {
        let snapshot = try await db.collection(Constants.Firestore.followsCollection)
            .whereField("followerUID", isEqualTo: followerUID)
            .getDocuments()
        
        return snapshot.documents.compactMap { $0.data()["listID"] as? String }
    }
    
    // MARK: - Snapshot Listener
    
    /// Attaches a real-time listener to a published list document.
    /// Returns a `ListenerRegistration` that the caller must retain and remove when done.
    /// `nonisolated` because Firestore listeners are internally thread-safe and
    /// `ListenerRegistration` is not `Sendable` — can't cross actor boundaries.
    nonisolated func addPublishedListListener(
        docID: String,
        onChange: @escaping @Sendable (PublishedListSnapshot?) -> Void
    ) -> ListenerRegistration {
        db.collection(Constants.Firestore.publishedListsCollection)
            .document(docID)
            .addSnapshotListener { snapshot, error in
                if let error {
                    Logger(subsystem: "com.flickswiper.app", category: "Firestore")
                        .error("Listener error for \(docID): \(error.localizedDescription)")
                    onChange(nil)
                    return
                }
                
                guard let snapshot, snapshot.exists, let data = snapshot.data() else {
                    onChange(nil)
                    return
                }
                
                // Parse on the callback thread (Firestore's background thread) to avoid
                // blocking the main actor. The caller is responsible for dispatching to main.
                let parsed = Self.parsePublishedListSnapshotStatic(docID: snapshot.documentID, data: data)
                onChange(parsed)
            }
    }
    
    // MARK: - Generate Share Link
    
    /// Constructs the Universal Link URL for a published list.
    func shareLink(for docID: String) -> URL? {
        URL(string: "\(Constants.URLs.deepLinkBase)/list/\(docID)")
    }
    
    // MARK: - Parsing Helpers
    
    private func parsePublishedListSnapshot(docID: String, data: [String: Any]) -> PublishedListSnapshot {
        Self.parsePublishedListSnapshotStatic(docID: docID, data: data)
    }
    
    /// Static version for use in non-isolated contexts (snapshot listener callbacks).
    private static func parsePublishedListSnapshotStatic(docID: String, data: [String: Any]) -> PublishedListSnapshot {
        let itemsArray = data["items"] as? [[String: Any]] ?? []
        let items: [PublishedListItem] = itemsArray.map { dict in
            PublishedListItem(
                tmdbID: dict["tmdbID"] as? Int ?? 0,
                mediaType: dict["mediaType"] as? String ?? "movie",
                title: dict["title"] as? String ?? "Unknown",
                posterPath: dict["posterPath"] as? String,
                dateAdded: (dict["dateAdded"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        
        return PublishedListSnapshot(
            docID: docID,
            ownerUID: data["ownerUID"] as? String ?? "",
            ownerDisplayName: data["ownerDisplayName"] as? String ?? "Unknown",
            name: data["name"] as? String ?? "Untitled",
            description: data["description"] as? String ?? "",
            items: items,
            itemCount: data["itemCount"] as? Int ?? items.count,
            isActive: data["isActive"] as? Bool ?? true,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )
    }
}
