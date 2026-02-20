import Foundation
import SwiftData
import os

/// Centralized write operations for SwipedItem persistence.
/// Keeps mutation logic out of views and provides consistent error handling.
///
/// Direction Transition Policy
/// ──────────────────────────
/// Direction hierarchy: seen > watchlist > skipped
/// - Promotions are always allowed (skipped→watchlist, skipped→seen, watchlist→seen)
/// - Demotions are silently ignored (seen→watchlist, seen→skipped, watchlist→skipped)
/// - Same-direction re-encounters update dateSwiped but preserve all user data
///
/// This prevents a re-encountered item in Discover (with "Show Previously Swiped" ON)
/// from silently vanishing out of the user's library when swiped left or bookmarked.
@MainActor
struct SwipedItemStore {
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "Persistence")

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Direction Hierarchy

    /// Numeric rank for direction comparison. Higher = more "committed".
    private static func directionRank(_ direction: String) -> Int {
        switch direction {
        case SwipedItem.directionSeen: return 2
        case SwipedItem.directionWatchlist: return 1
        default: return 0 // skipped or unknown
        }
    }

    /// Whether transitioning from `current` to `proposed` is allowed.
    /// Promotions and same-direction re-encounters are allowed; demotions are not.
    private static func isTransitionAllowed(from current: String, to proposed: String) -> Bool {
        directionRank(proposed) >= directionRank(current)
    }

    // MARK: - Write Operations

    @discardableResult
    func markAsSeen(from mediaItem: MediaItem, sourcePlatform: String? = nil) throws -> SwipedItem {
        if let existing = try findExisting(uniqueID: mediaItem.uniqueID) {
            // "seen" is the highest rank — always allowed
            existing.swipeDirection = SwipedItem.directionSeen
            existing.dateSwiped = Date()
            if let sp = sourcePlatform { existing.sourcePlatform = sp }
            try save()
            return existing
        }
        let swipedItem = SwipedItem(from: mediaItem, direction: .seen)
        swipedItem.sourcePlatform = sourcePlatform
        context.insert(swipedItem)
        try save()
        return swipedItem
    }

    @discardableResult
    func saveToWatchlist(from mediaItem: MediaItem, sourcePlatform: String? = nil) throws -> SwipedItem {
        if let existing = try findExisting(uniqueID: mediaItem.uniqueID) {
            // Only allow if current direction is not higher-ranked (i.e. don't demote "seen")
            if Self.isTransitionAllowed(from: existing.swipeDirection, to: SwipedItem.directionWatchlist) {
                existing.swipeDirection = SwipedItem.directionWatchlist
                existing.dateSwiped = Date()
                if let sp = sourcePlatform { existing.sourcePlatform = sp }
                try save()
            }
            // Either way, return the existing record unchanged or updated
            return existing
        }
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
        // Clean up any ListEntries referencing this item to prevent orphans
        let itemID = item.uniqueID
        let descriptor = FetchDescriptor<ListEntry>(
            predicate: #Predicate<ListEntry> { $0.itemID == itemID }
        )
        let entries = try context.fetch(descriptor)
        for entry in entries {
            context.delete(entry)
        }

        context.delete(item)
        try save()
    }

    func setPersonalRating(_ rating: Int, for item: SwipedItem) throws {
        item.personalRating = rating
        try save()
    }

    // MARK: - Lookup

    /// Look up an existing SwipedItem by its composite unique ID.
    /// Returns nil if no record exists.
    private func findExisting(uniqueID: String) throws -> SwipedItem? {
        let uid = uniqueID
        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate<SwipedItem> { $0.uniqueID == uid }
        )
        return try context.fetch(descriptor).first
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
