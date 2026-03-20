import Foundation
import SwiftData
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore
import os

/// Handles bidirectional sync of user library data (SwipedItems, UserLists, ListEntries)
/// between local SwiftData and Firestore.
///
/// Architecture (modeled on StreakSync's FirestoreGameResultSyncService):
/// - **Push-on-write**: Every local mutation also writes to Firestore immediately.
///   Firestore's built-in offline persistence queues writes when offline.
/// - **Incremental pull**: On app launch / periodic trigger, fetches only documents
///   modified since `lastSyncTimestamp` and merges into local data.
/// - **Merge rule**: Most recent `lastModified` wins, but direction hierarchy
///   (seen > watchlist > skipped) is never violated — a newer "watchlist" cannot
///   demote a local "seen" record.
///
/// Firestore structure:
/// ```
/// users/{uid}/swipedItems/{uniqueID}
/// users/{uid}/userLists/{uuid}
/// users/{uid}/listEntries/{uuid}
/// ```
///
/// Usage: Injected as environment object. AuthService triggers sync on sign-in.
@MainActor
@Observable
final class CloudSyncService {

    // MARK: - Public State

    enum SyncState: Equatable {
        case idle
        case syncing
        case synced(lastSyncDate: Date)
        case failed(String)

        static func == (lhs: SyncState, rhs: SyncState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.syncing, .syncing): return true
            case (.synced(let a), .synced(let b)): return a == b
            case (.failed(let a), .failed(let b)): return a == b
            default: return false
            }
        }
    }

    private(set) var syncState: SyncState = .idle

    /// The current Firebase Auth UID. Exposed for callers (e.g. SwipedItemStore)
    /// that need to set `ownerUID` on new records without importing FirebaseAuth.
    var currentUserUID: String? { currentUID }

    // MARK: - Private

    private var db: Firestore { Firestore.firestore() }
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "CloudSync")

    /// Current Firebase Auth UID. Nil if signed out.
    private var currentUID: String? { Auth.auth().currentUser?.uid }

    /// Per-user key for persisting last successful sync timestamp.
    private var lastSyncKey: String? {
        guard let uid = currentUID else { return nil }
        return "cloudSync_lastTimestamp_\(uid)"
    }

    private var lastSyncTimestamp: Date? {
        guard let key = lastSyncKey else { return nil }
        let ti = UserDefaults.standard.double(forKey: key)
        return ti > 0 ? Date(timeIntervalSince1970: ti) : nil
    }

    private func saveLastSyncTimestamp(_ date: Date) {
        guard let key = lastSyncKey else { return }
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key)
    }

    /// Clears the stored sync timestamp for the current user.
    /// Call on account deletion so a full (non-incremental) pull happens
    /// if they re-sign-in with the same UID later.
    func clearSyncTimestamp() {
        guard let key = lastSyncKey else { return }
        UserDefaults.standard.removeObject(forKey: key)
        syncState = .idle
        logger.info("Cleared sync timestamp")
    }

    // MARK: - Firestore Collection Refs

    private func swipedItemsRef(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("swipedItems")
    }

    private func userListsRef(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("userLists")
    }

    private func listEntriesRef(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("listEntries")
    }

    // MARK: - Direction Hierarchy

    /// Numeric rank for swipe direction. Higher = more committed.
    /// Used during merge to prevent demotions.
    private static func directionRank(_ direction: String) -> Int {
        switch direction {
        case "seen": return 2
        case "watchlist": return 1
        default: return 0 // skipped
        }
    }

    // MARK: - Claim Unclaimed Records (First Sign-In)

    /// Stamps all local records with `ownerUID = nil` with the given UID.
    /// Called once on first sign-in. After this, all records belong to this account.
    func claimUnownedRecords(uid: String, context: ModelContext) throws {
        logger.info("Claiming unclaimed records for UID: \(uid)")
        var claimedCount = 0

        let allItems = try context.fetch(FetchDescriptor<SwipedItem>())
        for item in allItems where item.ownerUID == nil {
            item.ownerUID = uid
            if item.lastModified == nil { item.lastModified = item.dateSwiped }
            claimedCount += 1
        }

        let allLists = try context.fetch(FetchDescriptor<UserList>())
        for list in allLists where list.ownerUID == nil {
            list.ownerUID = uid
            if list.lastModified == nil { list.lastModified = list.createdDate }
        }

        let allEntries = try context.fetch(FetchDescriptor<ListEntry>())
        for entry in allEntries where entry.ownerUID == nil {
            entry.ownerUID = uid
            if entry.lastModified == nil { entry.lastModified = entry.dateAdded }
        }

        try context.save()
        logger.info("Claimed \(claimedCount) swiped items + lists/entries for UID: \(uid)")
    }

    // MARK: - Full Sync Entry Point

    /// Bidirectional sync: pull remote changes, merge, push local changes.
    /// Called on app launch, after sign-in, and periodically while active.
    ///
    /// Re-entrancy guard: if a sync is already in progress, this call is a no-op.
    /// This prevents overlapping syncs from interleaving SwiftData writes
    /// (e.g., periodic timer firing while an account-switch sync is mid-await).
    func syncIfNeeded(context: ModelContext) async {
        guard let uid = currentUID else {
            logger.info("No authenticated user — skipping cloud sync")
            syncState = .idle
            return
        }

        // Re-entrancy guard — prevent overlapping sync operations
        guard syncState != .syncing else {
            logger.info("Sync already in progress — skipping")
            return
        }

        logger.info("Starting cloud sync for UID: \(uid)")
        syncState = .syncing

        do {
            // Phase 1: Pull remote changes and merge into local
            try await pullAndMerge(uid: uid, context: context)

            // Phase 2: Push local changes to Firestore
            try await pushLocalChanges(uid: uid, context: context)

            // Phase 3: Save sync timestamp
            let now = Date()
            saveLastSyncTimestamp(now)
            syncState = .synced(lastSyncDate: now)
            logger.info("Cloud sync completed successfully")
        } catch {
            logger.error("Cloud sync failed: \(error.localizedDescription)")
            syncState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Pull & Merge

    private func pullAndMerge(uid: String, context: ModelContext) async throws {
        let isIncremental = lastSyncTimestamp != nil

        // Pull SwipedItems
        let remoteItems = try await fetchRemoteSwipedItems(uid: uid, since: lastSyncTimestamp)
        if !remoteItems.isEmpty {
            try mergeSwipedItems(remoteItems, uid: uid, context: context)
            logger.info("Merged \(remoteItems.count) remote swiped items\(isIncremental ? " (incremental)" : " (full)")")
        }

        // Pull UserLists
        let remoteLists = try await fetchRemoteUserLists(uid: uid, since: lastSyncTimestamp)
        if !remoteLists.isEmpty {
            try mergeUserLists(remoteLists, uid: uid, context: context)
            logger.info("Merged \(remoteLists.count) remote user lists")
        }

        // Pull ListEntries
        let remoteEntries = try await fetchRemoteListEntries(uid: uid, since: lastSyncTimestamp)
        if !remoteEntries.isEmpty {
            try mergeListEntries(remoteEntries, uid: uid, context: context)
            logger.info("Merged \(remoteEntries.count) remote list entries")
        }
    }

    // MARK: - Firestore Fetch (Pull)

    private func fetchRemoteSwipedItems(uid: String, since: Date?) async throws -> [[String: Any]] {
        var query: Query = swipedItemsRef(uid: uid)
        if let since {
            query = query.whereField("lastModified", isGreaterThan: Timestamp(date: since))
        }
        let snapshot = try await query.getDocuments(source: .default)
        return snapshot.documents.map { doc in
            var data = doc.data()
            data["_docID"] = doc.documentID
            return data
        }
    }

    private func fetchRemoteUserLists(uid: String, since: Date?) async throws -> [[String: Any]] {
        var query: Query = userListsRef(uid: uid)
        if let since {
            query = query.whereField("lastModified", isGreaterThan: Timestamp(date: since))
        }
        let snapshot = try await query.getDocuments(source: .default)
        return snapshot.documents.map { doc in
            var data = doc.data()
            data["_docID"] = doc.documentID
            return data
        }
    }

    private func fetchRemoteListEntries(uid: String, since: Date?) async throws -> [[String: Any]] {
        var query: Query = listEntriesRef(uid: uid)
        if let since {
            query = query.whereField("lastModified", isGreaterThan: Timestamp(date: since))
        }
        let snapshot = try await query.getDocuments(source: .default)
        return snapshot.documents.map { doc in
            var data = doc.data()
            data["_docID"] = doc.documentID
            return data
        }
    }

    // MARK: - Merge Logic

    /// Merges remote SwipedItems into local SwiftData.
    /// Rule: most recent `lastModified` wins, but direction hierarchy is never violated.
    private func mergeSwipedItems(_ remoteDocs: [[String: Any]], uid: String, context: ModelContext) throws {
        // Build local lookup by uniqueID
        let allLocal = try context.fetch(FetchDescriptor<SwipedItem>())
        var localByID = Dictionary(uniqueKeysWithValues: allLocal.compactMap { item -> (String, SwipedItem)? in
            guard item.ownerUID == uid else { return nil }
            return (item.uniqueID, item)
        })

        for doc in remoteDocs {
            guard let uniqueID = doc["_docID"] as? String,
                  let mediaID = doc["mediaID"] as? Int,
                  let mediaType = doc["mediaType"] as? String,
                  let direction = doc["swipeDirection"] as? String,
                  let title = doc["title"] as? String else {
                logger.warning("Skipping malformed remote swiped item")
                continue
            }

            let remoteModified = (doc["lastModified"] as? Timestamp)?.dateValue() ?? Date.distantPast

            if let local = localByID[uniqueID] {
                // Existing record — merge by timestamp, respecting direction hierarchy
                let localModified = local.lastModified ?? Date.distantPast

                if remoteModified > localModified {
                    // Remote is newer — update local, but never demote direction
                    let remoteRank = Self.directionRank(direction)
                    let localRank = Self.directionRank(local.swipeDirection)

                    if remoteRank >= localRank {
                        // Remote direction is equal or higher rank — take it
                        local.swipeDirection = direction
                    }
                    // else: remote is a demotion, keep local direction

                    // Update non-direction fields from remote regardless
                    local.dateSwiped = (doc["dateSwiped"] as? Timestamp)?.dateValue() ?? local.dateSwiped
                    local.title = title
                    local.overview = doc["overview"] as? String ?? local.overview
                    local.posterPath = doc["posterPath"] as? String
                    local.releaseDate = doc["releaseDate"] as? String
                    local.rating = doc["rating"] as? Double
                    local.personalRating = doc["personalRating"] as? Int
                    local.genreIDsString = doc["genreIDsString"] as? String
                    local.sourcePlatform = doc["sourcePlatform"] as? String
                    local.lastModified = remoteModified
                }
                // else: local is newer — skip, will be pushed in push phase
            } else {
                // New remote record — insert locally
                let newItem = SwipedItem(
                    mediaID: mediaID,
                    mediaType: MediaItem.MediaType(rawValue: mediaType) ?? .movie,
                    swipeDirection: SwipedItem.SwipeDirection(rawValue: direction) ?? .skipped,
                    title: title,
                    overview: doc["overview"] as? String ?? "",
                    posterPath: doc["posterPath"] as? String,
                    releaseDate: doc["releaseDate"] as? String,
                    rating: doc["rating"] as? Double
                )
                newItem.personalRating = doc["personalRating"] as? Int
                newItem.genreIDsString = doc["genreIDsString"] as? String
                newItem.sourcePlatform = doc["sourcePlatform"] as? String
                newItem.dateSwiped = (doc["dateSwiped"] as? Timestamp)?.dateValue() ?? Date()
                newItem.lastModified = remoteModified
                newItem.ownerUID = uid
                context.insert(newItem)
                localByID[uniqueID] = newItem
            }
        }

        try context.save()
    }

    /// Merges remote UserLists into local SwiftData. Most recent `lastModified` wins.
    private func mergeUserLists(_ remoteDocs: [[String: Any]], uid: String, context: ModelContext) throws {
        let allLocal = try context.fetch(FetchDescriptor<UserList>())
        var localByID: [String: UserList] = [:]
        for list in allLocal where list.ownerUID == uid {
            localByID[list.id.uuidString] = list
        }

        for doc in remoteDocs {
            guard let docID = doc["_docID"] as? String,
                  let uuid = UUID(uuidString: docID),
                  let name = doc["name"] as? String else {
                logger.warning("Skipping malformed remote user list")
                continue
            }

            let remoteModified = (doc["lastModified"] as? Timestamp)?.dateValue() ?? Date.distantPast

            if let local = localByID[docID] {
                let localModified = local.lastModified ?? Date.distantPast
                if remoteModified > localModified {
                    local.name = name
                    local.sortOrder = doc["sortOrder"] as? Int ?? local.sortOrder
                    local.firestoreDocID = doc["firestoreDocID"] as? String
                    local.isPublished = doc["isPublished"] as? Bool ?? false
                    local.lastModified = remoteModified
                }
            } else {
                let newList = UserList(name: name, sortOrder: doc["sortOrder"] as? Int ?? 0)
                // Override auto-generated UUID with the one from Firestore
                newList.id = uuid
                newList.createdDate = (doc["createdDate"] as? Timestamp)?.dateValue() ?? Date()
                newList.firestoreDocID = doc["firestoreDocID"] as? String
                newList.isPublished = doc["isPublished"] as? Bool ?? false
                newList.lastModified = remoteModified
                newList.ownerUID = uid
                context.insert(newList)
                localByID[docID] = newList
            }
        }

        try context.save()
    }

    /// Merges remote ListEntries into local SwiftData. Most recent `lastModified` wins.
    private func mergeListEntries(_ remoteDocs: [[String: Any]], uid: String, context: ModelContext) throws {
        let allLocal = try context.fetch(FetchDescriptor<ListEntry>())
        var localByID: [String: ListEntry] = [:]
        for entry in allLocal where entry.ownerUID == uid {
            localByID[entry.id.uuidString] = entry
        }

        for doc in remoteDocs {
            guard let docID = doc["_docID"] as? String,
                  let uuid = UUID(uuidString: docID),
                  let listIDStr = doc["listID"] as? String,
                  let listID = UUID(uuidString: listIDStr),
                  let itemID = doc["itemID"] as? String else {
                logger.warning("Skipping malformed remote list entry")
                continue
            }

            let remoteModified = (doc["lastModified"] as? Timestamp)?.dateValue() ?? Date.distantPast

            if let local = localByID[docID] {
                let localModified = local.lastModified ?? Date.distantPast
                if remoteModified > localModified {
                    local.listID = listID
                    local.itemID = itemID
                    local.sortOrder = doc["sortOrder"] as? Int ?? local.sortOrder
                    local.lastModified = remoteModified
                }
            } else {
                let newEntry = ListEntry(listID: listID, itemID: itemID,
                                         sortOrder: doc["sortOrder"] as? Int ?? 0)
                newEntry.id = uuid
                newEntry.dateAdded = (doc["dateAdded"] as? Timestamp)?.dateValue() ?? Date()
                newEntry.lastModified = remoteModified
                newEntry.ownerUID = uid
                context.insert(newEntry)
                localByID[docID] = newEntry
            }
        }

        try context.save()
    }

    // MARK: - Push Local Changes

    /// Pushes locally modified records to Firestore.
    /// On first sync (no lastSyncTimestamp): pushes everything owned by this UID.
    /// On incremental sync: pushes only records modified since last sync.
    private func pushLocalChanges(uid: String, context: ModelContext) async throws {
        let since = lastSyncTimestamp

        // Push SwipedItems
        let allItems = try context.fetch(FetchDescriptor<SwipedItem>())
        let itemsToPush = allItems.filter { item in
            guard item.ownerUID == uid else { return false }
            guard let modified = item.lastModified else { return true } // nil = never synced
            if let since { return modified > since }
            return true // full sync
        }

        if !itemsToPush.isEmpty {
            logger.info("Pushing \(itemsToPush.count) swiped items to Firestore")
            try await batchUploadSwipedItems(itemsToPush, uid: uid)
        }

        // Push UserLists
        let allLists = try context.fetch(FetchDescriptor<UserList>())
        let listsToPush = allLists.filter { list in
            guard list.ownerUID == uid else { return false }
            guard let modified = list.lastModified else { return true }
            if let since { return modified > since }
            return true
        }

        if !listsToPush.isEmpty {
            logger.info("Pushing \(listsToPush.count) user lists to Firestore")
            try await batchUploadUserLists(listsToPush, uid: uid)
        }

        // Push ListEntries
        let allEntries = try context.fetch(FetchDescriptor<ListEntry>())
        let entriesToPush = allEntries.filter { entry in
            guard entry.ownerUID == uid else { return false }
            guard let modified = entry.lastModified else { return true }
            if let since { return modified > since }
            return true
        }

        if !entriesToPush.isEmpty {
            logger.info("Pushing \(entriesToPush.count) list entries to Firestore")
            try await batchUploadListEntries(entriesToPush, uid: uid)
        }
    }

    // MARK: - Batch Uploads (chunked for Firestore 500-op limit)

    private func batchUploadSwipedItems(_ items: [SwipedItem], uid: String) async throws {
        let ref = swipedItemsRef(uid: uid)
        for chunk in items.chunked(into: 400) {
            let batch = db.batch()
            for item in chunk {
                let docRef = ref.document(item.uniqueID)
                batch.setData(item.toFirestoreData(), forDocument: docRef, merge: true)
            }
            try await batch.commit()
        }
    }

    private func batchUploadUserLists(_ lists: [UserList], uid: String) async throws {
        let ref = userListsRef(uid: uid)
        for chunk in lists.chunked(into: 400) {
            let batch = db.batch()
            for list in chunk {
                let docRef = ref.document(list.id.uuidString)
                batch.setData(list.toFirestoreData(), forDocument: docRef, merge: true)
            }
            try await batch.commit()
        }
    }

    private func batchUploadListEntries(_ entries: [ListEntry], uid: String) async throws {
        let ref = listEntriesRef(uid: uid)
        for chunk in entries.chunked(into: 400) {
            let batch = db.batch()
            for entry in chunk {
                let docRef = ref.document(entry.id.uuidString)
                batch.setData(entry.toFirestoreData(), forDocument: docRef, merge: true)
            }
            try await batch.commit()
        }
    }

    // MARK: - Write-Through (Push Individual Changes)

    /// Pushes a single SwipedItem to Firestore. Called after every local mutation.
    func pushSwipedItem(_ item: SwipedItem) {
        guard let uid = currentUID, item.ownerUID == uid else { return }
        let ref = swipedItemsRef(uid: uid).document(item.uniqueID)
        // Firestore offline persistence queues this write automatically
        ref.setData(item.toFirestoreData(), merge: true) { [weak self] error in
            if let error {
                self?.logger.error("Failed to push swiped item \(item.uniqueID): \(error.localizedDescription)")
            }
        }
    }

    /// Pushes a single UserList to Firestore.
    func pushUserList(_ list: UserList) {
        guard let uid = currentUID, list.ownerUID == uid else { return }
        let ref = userListsRef(uid: uid).document(list.id.uuidString)
        ref.setData(list.toFirestoreData(), merge: true) { [weak self] error in
            if let error {
                self?.logger.error("Failed to push user list \(list.name): \(error.localizedDescription)")
            }
        }
    }

    /// Pushes a single ListEntry to Firestore.
    func pushListEntry(_ entry: ListEntry) {
        guard let uid = currentUID, entry.ownerUID == uid else { return }
        let ref = listEntriesRef(uid: uid).document(entry.id.uuidString)
        ref.setData(entry.toFirestoreData(), merge: true) { [weak self] error in
            if let error {
                self?.logger.error("Failed to push list entry \(entry.id): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Delete from Firestore

    /// Deletes a SwipedItem from Firestore. Called when user deletes locally.
    func deleteSwipedItem(uniqueID: String) {
        guard let uid = currentUID else { return }
        swipedItemsRef(uid: uid).document(uniqueID).delete { [weak self] error in
            if let error {
                self?.logger.error("Failed to delete swiped item \(uniqueID) from Firestore: \(error.localizedDescription)")
            }
        }
    }

    /// Deletes a UserList and all its entries from Firestore.
    /// Chunked into batches of 400 to stay under Firestore's 500-op limit.
    func deleteUserList(listID: UUID, entryIDs: [UUID]) {
        guard let uid = currentUID else { return }

        // Build all delete operations: 1 list doc + N entry docs
        var allRefs: [DocumentReference] = [userListsRef(uid: uid).document(listID.uuidString)]
        for entryID in entryIDs {
            allRefs.append(listEntriesRef(uid: uid).document(entryID.uuidString))
        }

        // Chunk to stay under Firestore's 500-op batch limit
        for chunk in allRefs.chunked(into: 400) {
            let batch = db.batch()
            for ref in chunk {
                batch.deleteDocument(ref)
            }
            batch.commit { [weak self] error in
                if let error {
                    self?.logger.error("Failed to delete user list from Firestore: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Deletes a single ListEntry from Firestore.
    func deleteListEntry(entryID: UUID) {
        guard let uid = currentUID else { return }
        listEntriesRef(uid: uid).document(entryID.uuidString).delete { [weak self] error in
            if let error {
                self?.logger.error("Failed to delete list entry from Firestore: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Account Switch

    /// Handles switching to a different user account.
    /// 1. Clears all local library data (SwipedItem, UserList, ListEntry)
    /// 2. Pulls the new account's data from Firestore
    ///
    /// The previous account's data is safe because `syncIfNeeded` was called
    /// before sign-out (ensuring cloud is up to date).
    func handleAccountSwitch(newUID: String, context: ModelContext) async throws {
        logger.info("Account switch: clearing local data and pulling for UID: \(newUID)")

        // 1. Clear all local library data
        let allItems = try context.fetch(FetchDescriptor<SwipedItem>())
        for item in allItems { context.delete(item) }

        let allLists = try context.fetch(FetchDescriptor<UserList>())
        for list in allLists { context.delete(list) }

        let allEntries = try context.fetch(FetchDescriptor<ListEntry>())
        for entry in allEntries { context.delete(entry) }

        // Also clear followed lists (they're per-account Firestore cache)
        let followedLists = try context.fetch(FetchDescriptor<FollowedList>())
        for list in followedLists { context.delete(list) }

        let followedItems = try context.fetch(FetchDescriptor<FollowedListItem>())
        for item in followedItems { context.delete(item) }

        try context.save()
        logger.info("Local data cleared for account switch")

        // 2. Reset sync timestamp so full pull happens
        if let key = lastSyncKey {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // 3. Pull the new account's data (full sync, no timestamp filter)
        try await pullAndMerge(uid: newUID, context: context)
        try context.save()

        let now = Date()
        saveLastSyncTimestamp(now)
        syncState = .synced(lastSyncDate: now)
        logger.info("Account switch complete — pulled data for UID: \(newUID)")
    }

    // MARK: - Bulk Delete (Settings Reset Operations)

    /// Deletes multiple SwipedItems from Firestore by their uniqueIDs.
    /// Called when user resets skipped items, all items, or clears watchlist.
    func bulkDeleteSwipedItems(uniqueIDs: [String]) {
        guard let uid = currentUID, !uniqueIDs.isEmpty else { return }
        let ref = swipedItemsRef(uid: uid)
        // Chunk into batches of 400 (leaving room under 500 limit)
        for chunk in uniqueIDs.chunked(into: 400) {
            let batch = db.batch()
            for id in chunk {
                batch.deleteDocument(ref.document(id))
            }
            batch.commit { [weak self] error in
                if let error {
                    self?.logger.error("Bulk delete failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Deletes all list entries for given entry IDs from Firestore.
    func bulkDeleteListEntries(entryIDs: [UUID]) {
        guard let uid = currentUID, !entryIDs.isEmpty else { return }
        let ref = listEntriesRef(uid: uid)
        for chunk in entryIDs.chunked(into: 400) {
            let batch = db.batch()
            for id in chunk {
                batch.deleteDocument(ref.document(id.uuidString))
            }
            batch.commit { [weak self] error in
                if let error {
                    self?.logger.error("Bulk delete entries failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Firestore Serialization

extension SwipedItem {
    /// Converts this SwipedItem to a Firestore-compatible dictionary.
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "mediaID": mediaID,
            "mediaType": mediaType,
            "swipeDirection": swipeDirection,
            "dateSwiped": Timestamp(date: dateSwiped),
            "title": title,
            "overview": overview,
            "lastModified": Timestamp(date: lastModified ?? dateSwiped)
        ]
        if let posterPath { data["posterPath"] = posterPath }
        if let releaseDate { data["releaseDate"] = releaseDate }
        if let rating { data["rating"] = rating }
        if let personalRating { data["personalRating"] = personalRating }
        if let genreIDsString { data["genreIDsString"] = genreIDsString }
        if let sourcePlatform { data["sourcePlatform"] = sourcePlatform }
        return data
    }
}

extension UserList {
    /// Converts this UserList to a Firestore-compatible dictionary.
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "name": name,
            "createdDate": Timestamp(date: createdDate),
            "sortOrder": sortOrder,
            "isPublished": isPublished,
            "lastModified": Timestamp(date: lastModified ?? createdDate)
        ]
        if let firestoreDocID { data["firestoreDocID"] = firestoreDocID }
        return data
    }
}

extension ListEntry {
    /// Converts this ListEntry to a Firestore-compatible dictionary.
    func toFirestoreData() -> [String: Any] {
        [
            "listID": listID.uuidString,
            "itemID": itemID,
            "dateAdded": Timestamp(date: dateAdded),
            "sortOrder": sortOrder,
            "lastModified": Timestamp(date: lastModified ?? dateAdded)
        ]
    }
}

// MARK: - Array Chunking Utility

extension Array {
    /// Splits the array into chunks of the specified size.
    /// The last chunk may be smaller than `size`.
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
