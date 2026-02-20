import Foundation
import SwiftData

/// A list published by another user that the current user is following.
///
/// This is a local cache of the Firestore `publishedLists` document data.
/// The source of truth is always Firestore — local data is updated via
/// snapshot listeners while the app is active.
///
/// Items are stored separately in `FollowedListItem` for clean querying,
/// linked by `firestoreDocID`.
@Model
final class FollowedList {
    /// Firestore document ID of the published list. Serves as the unique key.
    @Attribute(.unique) var firestoreDocID: String
    
    /// Cached list name from Firestore.
    var name: String
    
    /// Owner's display name, e.g. "Alex". Shown as "by Alex" in the UI.
    var ownerDisplayName: String
    
    /// Firebase Auth UID of the list owner. Used to prevent self-follow
    /// and to detect owner account deletion.
    var ownerUID: String
    
    /// Cached item count for display without fetching items.
    var itemCount: Int
    
    /// When the current user followed this list.
    var followedAt: Date
    
    /// When items were last fetched/updated from Firestore.
    var lastFetchedAt: Date?
    
    /// Whether the list is still active. Set to false when the owner
    /// unpublishes or deletes their account. UI shows "no longer maintained."
    var isActive: Bool = true
    
    init(
        firestoreDocID: String,
        name: String,
        ownerDisplayName: String,
        ownerUID: String,
        itemCount: Int,
        followedAt: Date = Date()
    ) {
        self.firestoreDocID = firestoreDocID
        self.name = name
        self.ownerDisplayName = ownerDisplayName
        self.ownerUID = ownerUID
        self.itemCount = itemCount
        self.followedAt = followedAt
        self.lastFetchedAt = nil
        self.isActive = true
    }
}
