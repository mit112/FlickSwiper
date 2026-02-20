import Foundation
import SwiftUI
import SwiftData
import os

/// ViewModel for the swipe view
/// Handles fetching content, filtering swiped items, and managing swipe actions.
///
/// Explicitly `@MainActor` because all properties drive UI bindings via `@Observable`.
@MainActor
@Observable
final class SwipeViewModel {
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "SwipeViewModel")
    
    // MARK: - Published Properties
    
    /// Queue of media items to display
    private(set) var mediaItems: [MediaItem] = []
    
    /// Currently selected discovery method
    var selectedMethod: DiscoveryMethod = .popular {
        didSet {
            if oldValue != selectedMethod {
                clearUndoStack() // Clear undo when changing category
                if selectedMethod.watchProviderID == nil {
                    selectedSort = .popular
                }
                scheduleContentReload()
                saveSelectedMethod()
            }
        }
    }

    /// Sort option for streaming service discovery (only applies when a streaming method is selected)
    var selectedSort: StreamingSortOption = .popular {
        didSet {
            if oldValue != selectedSort {
                scheduleContentReload()
            }
        }
    }
    
    /// Content type filter (movies, TV shows, or all)
    var contentTypeFilter: ContentTypeFilter = .all {
        didSet {
            if oldValue != contentTypeFilter {
                clearUndoStack() // Clear undo when changing filter
                scheduleContentReload()
            }
        }
    }
    
    /// Year filter - minimum year (nil = no filter)
    var yearFilterMin: Int? = nil {
        didSet {
            if oldValue != yearFilterMin {
                scheduleContentReload()
            }
        }
    }
    
    /// Year filter - maximum year (nil = no filter)
    var yearFilterMax: Int? = nil {
        didSet {
            if oldValue != yearFilterMax {
                scheduleContentReload()
            }
        }
    }
    
    /// Genre filter (nil = no filter)
    var selectedGenre: Genre? = nil {
        didSet {
            if oldValue != selectedGenre {
                scheduleContentReload()
            }
        }
    }
    
    /// Whether genre filter is active
    var isGenreFilterActive: Bool {
        selectedGenre != nil
    }
    
    /// Clear genre filter
    func clearGenreFilter() {
        selectedGenre = nil
    }
    
    /// Whether to include previously swiped items (show them again)
    /// Reads from UserDefaults (written by @AppStorage in SettingsView)
    var includeSwipedItems: Bool = UserDefaults.standard.bool(forKey: Constants.StorageKeys.includeSwipedItems)
    
    /// Sync all settings and state that can change while the Discover tab is off-screen.
    /// Called from SwipeView's `.onAppear` on every tab switch.
    ///
    /// Handles two cases:
    /// 1. The "Show Previously Swiped" toggle changed in Settings.
    /// 2. Swiped items were deleted in Settings (reset skipped, reset all, clear watchlist),
    ///    which means `swipedIDs` is stale and items should reappear in discovery.
    func syncWithSettings(context: ModelContext) {
        var needsReload = false
        
        // Check if the "include swiped" toggle changed
        let currentToggle = UserDefaults.standard.bool(forKey: Constants.StorageKeys.includeSwipedItems)
        if currentToggle != includeSwipedItems {
            includeSwipedItems = currentToggle
            needsReload = true
        }
        
        // Reload swiped IDs from SwiftData — picks up any deletions from Settings
        let previousCount = swipedIDs.count
        loadSwipedIDs(context: context)
        if swipedIDs.count != previousCount {
            needsReload = true
        }
        
        if needsReload {
            scheduleContentReload()
        }
    }
    
    /// Whether year filter is active
    var isYearFilterActive: Bool {
        yearFilterMin != nil || yearFilterMax != nil
    }
    
    /// Clear year filter
    func clearYearFilter() {
        yearFilterMin = nil
        yearFilterMax = nil
    }
    
    /// Loading state
    private(set) var isLoading: Bool = false
    
    /// Error message to display (nil when no error)
    private(set) var errorMessage: String?
    
    /// Whether the last failure was due to no network connectivity.
    /// Drives a dedicated offline state in SwipeView.
    private(set) var isOffline: Bool = false
    
    /// Whether we've reached the end of available content
    private(set) var hasReachedEnd: Bool = false
    
    /// Count of swiped items (for display)
    var swipedCount: Int { swipedIDs.count }
    
    // MARK: - Undo Support
    
    /// Captures the state needed to reverse a single swipe action.
    struct UndoEntry {
        let item: MediaItem
        let newDirection: SwipedItem.SwipeDirection
        /// `nil` when the swipe created a new record (undo = delete record).
        /// Non-nil with the previous direction string when a pre-existing record
        /// was encountered (undo = restore that direction).
        let previousDirection: String?
    }
    
    /// Stack of recently swiped items for undo functionality
    private(set) var undoStack: [UndoEntry] = []
    
    /// Maximum number of items to keep in undo stack
    private let maxUndoStackSize = 10
    
    /// Whether undo is available
    var canUndo: Bool { !undoStack.isEmpty }
    
    // MARK: - Private Properties
    
    /// Set of swiped item unique IDs for O(1) lookup
    private var swipedIDs: Set<String> = []
    
    /// Current page for pagination
    private var currentPage: Int = 1
    
    /// Media service instance (injectable for testing)
    private let mediaService: any MediaServiceProtocol
    
    /// Minimum items before triggering pre-fetch
    private let prefetchThreshold = 5
    
    /// Image prefetch cache
    private var prefetchedImages: Set<String> = []
    private var imagePrefetchTasks: [String: Task<Void, Never>] = [:]
    
    /// Debounce task for filter changes
    private var filterDebounceTask: Task<Void, Never>?
    
    /// Debounce delay in milliseconds
    private let debounceDelay: UInt64 = 300_000_000 // 300ms in nanoseconds
    
    // MARK: - Initialization
    
    /// Initialize with optional media service for dependency injection
    /// - Parameter mediaService: Service to use for fetching media content. Defaults to TMDBService.
    init(mediaService: any MediaServiceProtocol = TMDBService()) {
        self.mediaService = mediaService
        loadSelectedMethod()
    }
    
    // MARK: - Public Methods
    
    /// Load initial content and swiped IDs
    func loadInitialContent(context: ModelContext) async {
        loadSwipedIDs(context: context)
        await loadContent()
    }
    
    /// Load swiped IDs from SwiftData for filtering
    func loadSwipedIDs(context: ModelContext) {
        let descriptor = FetchDescriptor<SwipedItem>()
        
        do {
            let swipedItems = try context.fetch(descriptor)
            self.swipedIDs = Set(swipedItems.map { $0.uniqueID })
        } catch {
            logger.error("Error loading swiped IDs: \(error.localizedDescription)")
        }
    }
    
    /// Load more content from the API.
    ///
    /// If most fetched items were already swiped, automatically fetches additional pages
    /// up to `maxAutoPages` to keep the card queue populated.
    func loadContent() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        isOffline = false
        
        // Limit consecutive auto-fetch attempts to prevent runaway API calls
        // when the user has swiped through most available content.
        let maxAutoPages = 5
        var autoPageAttempts = 0
        var consecutiveZeroYield = 0
        
        while autoPageAttempts < maxAutoPages {
            do {
                let newItems = try await mediaService.fetchContent(
                    for: selectedMethod,
                    contentType: contentTypeFilter,
                    genre: selectedGenre,
                    page: currentPage,
                    sort: selectedSort,
                    yearMin: yearFilterMin,
                    yearMax: yearFilterMax
                )
                
                let filteredItems = filterSwipedItems(newItems)
                
                if filteredItems.isEmpty && newItems.isEmpty {
                    hasReachedEnd = true
                    break
                }
                
                // Deduplicate against items already in the queue.
                // TMDB pagination can return the same item across pages.
                let existingIDs = Set(mediaItems.map(\.uniqueID))
                let deduped = filteredItems.filter { !existingIDs.contains($0.uniqueID) }
                mediaItems.append(contentsOf: deduped)
                currentPage += 1
                
                // If we got enough usable items, stop fetching
                if deduped.count >= 5 || hasReachedEnd {
                    break
                }
                
                // Track consecutive pages where TMDB returned content that passed
                // the swiped filter but was all duplicate of items already in our queue.
                // This detects TMDB pagination overlap specifically — not swiped-item
                // filtering (which is handled by the autoPageAttempts limit).
                if deduped.isEmpty && !filteredItems.isEmpty {
                    consecutiveZeroYield += 1
                    if consecutiveZeroYield >= 2 {
                        hasReachedEnd = true
                        break
                    }
                } else if !deduped.isEmpty {
                    consecutiveZeroYield = 0
                }
                
                // Most items were filtered out — try another page
                autoPageAttempts += 1
                
            } catch {
                isOffline = NetworkError.isOffline(error)
                errorMessage = error.localizedDescription
                break
            }
        }
        
        isLoading = false
    }
    
    /// Reset and reload content (when changing discovery method)
    func resetAndLoadContent() async {
        mediaItems = []
        currentPage = 1
        hasReachedEnd = false
        await loadContent()
    }
    
    /// Schedule content reload with debouncing
    /// Prevents multiple rapid API calls when changing filters quickly
    private func scheduleContentReload() {
        // Cancel any existing debounce task
        filterDebounceTask?.cancel()
        
        // Create new debounced task
        filterDebounceTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: debounceDelay)
                // Only proceed if task wasn't cancelled
                guard !Task.isCancelled else { return }
                await resetAndLoadContent()
            } catch {
                // Task was cancelled, ignore
            }
        }
    }
    
    // MARK: - Direction Transition Policy
    //
    // Direction hierarchy: seen (2) > watchlist (1) > skipped (0)
    // Promotions allowed, demotions silently ignored.
    
    /// Numeric rank for direction comparison. Higher = more "committed".
    private static func directionRank(_ direction: String) -> Int {
        switch direction {
        case SwipedItem.directionSeen: return 2
        case SwipedItem.directionWatchlist: return 1
        default: return 0
        }
    }
    
    /// Whether transitioning from `current` to `proposed` is allowed.
    private static func isTransitionAllowed(from current: String, to proposed: String) -> Bool {
        directionRank(proposed) >= directionRank(current)
    }
    
    // MARK: - Swipe Actions
    
    /// Handle swipe right (mark as seen).
    /// "Seen" is the highest rank — always allowed on any existing record.
    @discardableResult
    func swipeRight(item: MediaItem, context: ModelContext) -> SwipedItem {
        let sourcePlatform = selectedMethod.watchProviderID != nil ? selectedMethod.rawValue : nil
        
        let swipedItem: SwipedItem
        let previousDirection: String?
        
        if let existing = fetchExisting(uniqueID: item.uniqueID, context: context) {
            previousDirection = existing.swipeDirection
            // "seen" is highest rank — always a valid transition
            existing.swipeDirection = SwipedItem.directionSeen
            existing.dateSwiped = Date()
            if let sp = sourcePlatform { existing.sourcePlatform = sp }
            swipedItem = existing
        } else {
            previousDirection = nil
            let newItem = SwipedItem(from: item, direction: .seen)
            newItem.sourcePlatform = sourcePlatform
            context.insert(newItem)
            swipedItem = newItem
        }
        
        do {
            try context.save()
            swipedIDs.insert(item.uniqueID)
            pushUndo(UndoEntry(item: item, newDirection: .seen, previousDirection: previousDirection))
            removeFromQueue(item: item)
            HapticManager.seen()
        } catch {
            logger.error("Error saving swipe right: \(error.localizedDescription)")
        }
        return swipedItem
    }
    
    /// Handle swipe left (skip).
    /// Skipping a "seen" or "watchlist" item only removes the card from the queue
    /// — it does NOT demote the record. The library stays intact.
    func swipeLeft(item: MediaItem, context: ModelContext) {
        let sourcePlatform = selectedMethod.watchProviderID != nil ? selectedMethod.rawValue : nil
        
        let previousDirection: String?
        
        if let existing = fetchExisting(uniqueID: item.uniqueID, context: context) {
            previousDirection = existing.swipeDirection
            // Only demote if transition is allowed (skipped→skipped is a no-op)
            if Self.isTransitionAllowed(from: existing.swipeDirection, to: SwipedItem.directionSkipped) {
                existing.swipeDirection = SwipedItem.directionSkipped
                existing.dateSwiped = Date()
                if let sp = sourcePlatform { existing.sourcePlatform = sp }
            }
            // If not allowed (e.g. seen→skipped), leave the record untouched
        } else {
            previousDirection = nil
            let swipedItem = SwipedItem(from: item, direction: .skipped)
            swipedItem.sourcePlatform = sourcePlatform
            context.insert(swipedItem)
        }
        
        do {
            try context.save()
            swipedIDs.insert(item.uniqueID)
            pushUndo(UndoEntry(item: item, newDirection: .skipped, previousDirection: previousDirection))
            removeFromQueue(item: item)
            HapticManager.skip()
        } catch {
            logger.error("Error saving swipe left: \(error.localizedDescription)")
        }
    }
    
    /// Handle swipe up / bookmark (add to watchlist from Discover).
    /// Watchlisting a "seen" item is a demotion — silently ignored.
    func swipeUp(item: MediaItem, context: ModelContext) {
        let sourcePlatform = selectedMethod.watchProviderID != nil ? selectedMethod.rawValue : nil
        
        let previousDirection: String?
        
        if let existing = fetchExisting(uniqueID: item.uniqueID, context: context) {
            previousDirection = existing.swipeDirection
            if Self.isTransitionAllowed(from: existing.swipeDirection, to: SwipedItem.directionWatchlist) {
                existing.swipeDirection = SwipedItem.directionWatchlist
                existing.dateSwiped = Date()
                if let sp = sourcePlatform { existing.sourcePlatform = sp }
            }
        } else {
            previousDirection = nil
            let swipedItem = SwipedItem(from: item, direction: .watchlist)
            swipedItem.sourcePlatform = sourcePlatform
            context.insert(swipedItem)
        }
        
        do {
            try context.save()
            swipedIDs.insert(item.uniqueID)
            pushUndo(UndoEntry(item: item, newDirection: .watchlist, previousDirection: previousDirection))
            removeFromQueue(item: item)
            HapticManager.seen()
        } catch {
            logger.error("Error saving swipe up (watchlist): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Lookup
    
    /// Look up an existing SwipedItem by composite unique ID.
    private func fetchExisting(uniqueID: String, context: ModelContext) -> SwipedItem? {
        let uid = uniqueID
        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate<SwipedItem> { $0.uniqueID == uid }
        )
        return try? context.fetch(descriptor).first
    }
    
    // MARK: - Undo
    
    /// Undo the last swipe action.
    ///
    /// - New records (previousDirection == nil): deletes the SwipedItem and removes from swipedIDs.
    /// - Pre-existing records: restores the previous direction without deleting.
    func undoLastSwipe(context: ModelContext) {
        guard let entry = undoStack.popLast() else { return }
        
        let itemUniqueID = entry.item.uniqueID
        
        do {
            if let previousDirection = entry.previousDirection {
                // Record pre-existed — restore its original direction
                if let existing = fetchExisting(uniqueID: itemUniqueID, context: context) {
                    existing.swipeDirection = previousDirection
                }
                // swipedIDs: item was already tracked before the swipe, leave it
            } else {
                // Record was newly created — delete it
                swipedIDs.remove(itemUniqueID)
                let descriptor = FetchDescriptor<SwipedItem>(
                    predicate: #Predicate<SwipedItem> { $0.uniqueID == itemUniqueID }
                )
                let records = try context.fetch(descriptor)
                for record in records {
                    context.delete(record)
                }
            }
            
            try context.save()
            mediaItems.insert(entry.item, at: 0)
            HapticManager.undo()
            
        } catch {
            logger.error("Error undoing swipe: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Undo Stack Management
    
    /// Push an entry onto the undo stack, evicting the oldest if at capacity.
    private func pushUndo(_ entry: UndoEntry) {
        undoStack.append(entry)
        if undoStack.count > maxUndoStackSize {
            undoStack.removeFirst()
        }
    }
    
    /// Clear the undo stack (called when switching categories)
    func clearUndoStack() {
        undoStack.removeAll()
    }
    
    /// Check if we need to load more content
    func loadMoreIfNeeded() {
        if mediaItems.count < prefetchThreshold && !isLoading && !hasReachedEnd {
            Task { await loadContent() }
        }
        
        // Prefetch images for upcoming cards
        prefetchUpcomingImages()
    }
    
    /// Prefetch images for smooth transitions (w500 for cards) and for Already Seen (w185 thumbnails)
    func prefetchUpcomingImages() {
        // Prefetch next 5 card images (poster + thumbnail so Already Seen has them cached)
        let itemsToPrefetch = Array(mediaItems.prefix(5))
        let activeIDs = Set(itemsToPrefetch.map(\.uniqueID))

        // Cancel stale downloads when the visible queue changes.
        for (id, task) in imagePrefetchTasks where !activeIDs.contains(id) {
            task.cancel()
            imagePrefetchTasks[id] = nil
        }
        
        for item in itemsToPrefetch {
            guard !prefetchedImages.contains(item.uniqueID) else { continue }
            guard imagePrefetchTasks[item.uniqueID] == nil else { continue }
            guard let posterURL = item.posterURL else { continue }
            
            // Build w185 thumbnail URL (same as SeenItemCard) so Already Seen list can use cache
            let thumbnailURL = item.posterPath.flatMap { path in
                URL(string: "https://image.tmdb.org/t/p/w185\(path)")
            }
            
            // Start image downloads in background (poster for swipe card, thumbnail for Already Seen)
            let itemID = item.uniqueID
            imagePrefetchTasks[itemID] = Task(priority: .background) {
                defer { imagePrefetchTasks[itemID] = nil }
                guard !Task.isCancelled else { return }
                do {
                    let (_, _) = try await URLSession.shared.data(from: posterURL)
                } catch {}
                if let thumbURL = thumbnailURL {
                    guard !Task.isCancelled else { return }
                    do {
                        let (_, _) = try await URLSession.shared.data(from: thumbURL)
                    } catch {}
                }
                guard !Task.isCancelled else { return }
                prefetchedImages.insert(itemID)
            }
        }
    }
    
    /// Get the top visible cards (for stacking effect)
    var visibleCards: [MediaItem] {
        Array(mediaItems.prefix(3))
    }
    
    /// Get the current top card
    var currentCard: MediaItem? {
        mediaItems.first
    }
    
    // MARK: - Private Methods
    
    /// Filter items based on all active filters (swiped, year range)
    private func filterSwipedItems(_ items: [MediaItem]) -> [MediaItem] {
        var filtered = items
        
        // Filter by swiped status
        if !includeSwipedItems {
            filtered = filtered.filter { !swipedIDs.contains($0.uniqueID) }
        }
        
        // Filter by year range
        if yearFilterMin != nil || yearFilterMax != nil {
            filtered = filtered.filter { item in
                guard let releaseDate = item.releaseDate,
                      releaseDate.count >= 4,
                      let year = Int(releaseDate.prefix(4)) else {
                    return false // Exclude items without valid year
                }
                
                if let minYear = yearFilterMin, year < minYear {
                    return false
                }
                if let maxYear = yearFilterMax, year > maxYear {
                    return false
                }
                return true
            }
        }
        
        return filtered
    }
    
    /// Remove item from the queue after swiping
    private func removeFromQueue(item: MediaItem) {
        mediaItems.removeAll { $0.uniqueID == item.uniqueID }
        loadMoreIfNeeded()
    }
    
    /// Public helper to remove a card from the stack and mark it as swiped
    /// without creating a new SwipedItem record. Useful for flows like
    /// watchlist bookmarking where the model has already been saved.
    func removeCardFromStack(item: MediaItem) {
        // Ensure this item's ID is treated as swiped so it won't reappear
        swipedIDs.insert(item.uniqueID)
        removeFromQueue(item: item)
    }
    
    /// Save selected discovery method to UserDefaults
    private func saveSelectedMethod() {
        UserDefaults.standard.set(selectedMethod.rawValue, forKey: Constants.StorageKeys.selectedDiscoveryMethod)
    }
    
    /// Load selected discovery method from UserDefaults
    private func loadSelectedMethod() {
        if let savedMethod = UserDefaults.standard.string(forKey: Constants.StorageKeys.selectedDiscoveryMethod),
           let method = DiscoveryMethod(rawValue: savedMethod) {
            selectedMethod = method
        }
    }
}
