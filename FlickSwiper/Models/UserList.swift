import Foundation
import SwiftData

/// A user-created list for organizing seen items (e.g. "Date Night", "Comfort Rewatches")
///
/// V3 additions: `firestoreDocID`, `isPublished`, `lastSyncedAt` — all optional
/// with defaults so the V2→V3 migration is lightweight (no data transformation).
@Model
final class UserList {
    var id: UUID
    var name: String
    var createdDate: Date
    var sortOrder: Int
    
    // MARK: - V3 Social Lists Fields
    
    /// Firestore document ID when this list is published. Nil = local only.
    /// Set on publish, cleared on unpublish. A new doc ID is generated on re-publish.
    var firestoreDocID: String?
    
    /// Quick check for published state without nil-testing firestoreDocID.
    var isPublished: Bool = false
    
    /// When this list was last successfully synced to Firestore.
    var lastSyncedAt: Date?
    
    // MARK: - Initialization
    
    init(name: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.sortOrder = sortOrder
        self.firestoreDocID = nil
        self.isPublished = false
        self.lastSyncedAt = nil
    }
    
    /// Resolve items belonging to this list from all entries and all swiped items
    func items(entries: [ListEntry], allItems: [SwipedItem]) -> [SwipedItem] {
        let itemIDs = entries
            .filter { $0.listID == self.id }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.itemID)
        let itemMap = Dictionary(uniqueKeysWithValues: allItems.map { ($0.uniqueID, $0) })
        return itemIDs.compactMap { itemMap[$0] }
    }
}
