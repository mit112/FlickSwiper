import Foundation
import SwiftData

/// Join table linking a SwipedItem to a UserList
/// Uses UUID references instead of SwiftData relationships for predictability
@Model
final class ListEntry {
    var id: UUID
    var listID: UUID        // References UserList.id
    var itemID: String      // References SwipedItem.uniqueID
    var dateAdded: Date
    var sortOrder: Int
    
    init(listID: UUID, itemID: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.listID = listID
        self.itemID = itemID
        self.dateAdded = Date()
        self.sortOrder = sortOrder
    }
}
