import Foundation
import SwiftData
import os

/// Centralized write operations for SwipedItem persistence.
/// Keeps mutation logic out of views and provides consistent error handling.
@MainActor
struct SwipedItemStore {
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "Persistence")

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func markAsSeen(from mediaItem: MediaItem, sourcePlatform: String? = nil) throws -> SwipedItem {
        let swipedItem = SwipedItem(from: mediaItem, direction: .seen)
        swipedItem.sourcePlatform = sourcePlatform
        context.insert(swipedItem)
        try save()
        return swipedItem
    }

    @discardableResult
    func saveToWatchlist(from mediaItem: MediaItem, sourcePlatform: String? = nil) throws -> SwipedItem {
        let swipedItem = SwipedItem(from: mediaItem, direction: .watchlist)
        swipedItem.sourcePlatform = sourcePlatform
        context.insert(swipedItem)
        try save()
        return swipedItem
    }

    func moveWatchlistToSeen(_ item: SwipedItem) throws {
        item.swipeDirection = SwipedItem.directionSeen
        item.dateSwiped = Date()
        try save()
    }

    func remove(_ item: SwipedItem) throws {
        context.delete(item)
        try save()
    }

    func setPersonalRating(_ rating: Int, for item: SwipedItem) throws {
        item.personalRating = rating
        try save()
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            logger.error("Failed to save SwiftData context: \(error.localizedDescription)")
            throw error
        }
    }
}
