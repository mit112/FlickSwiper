import Foundation
import SwiftData

/// A user-created list for organizing seen items (e.g. "Date Night", "Comfort Rewatches")
@Model
final class UserList {
    var id: UUID
    var name: String
    var createdDate: Date
    var sortOrder: Int
    
    init(name: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.sortOrder = sortOrder
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
