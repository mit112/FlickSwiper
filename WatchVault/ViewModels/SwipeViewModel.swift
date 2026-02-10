import Foundation
import SwiftUI
import SwiftData

/// ViewModel for the swipe view
/// Handles fetching content, filtering swiped items, and managing swipe actions
@Observable
final class SwipeViewModel {
    
    // MARK: - Published Properties
    
    /// Queue of media items to display
    var mediaItems: [MediaItem] = []
    
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
    var includeSwipedItems: Bool = UserDefaults.standard.bool(forKey: "includeSwipedItems")
    
    /// Check if the setting changed (e.g. user toggled in Settings) and reload if needed
    func syncIncludeSwipedSetting() {
        let current = UserDefaults.standard.bool(forKey: "includeSwipedItems")
        if current != includeSwipedItems {
            includeSwipedItems = current
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
    var isLoading: Bool = false
    
    /// Error message to display
    var errorMessage: String?
    
    /// Whether we've reached the end of available content
    var hasReachedEnd: Bool = false
    
    /// Count of swiped items (for display)
    var swipedCount: Int { swipedIDs.count }
    
    // MARK: - Undo Support
    
    /// Stack of recently swiped items for undo functionality
    private(set) var undoStack: [(item: MediaItem, direction: SwipedItem.SwipeDirection)] = []
    
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
        await loadSwipedIDs(context: context)
        await loadContent()
    }
    
    /// Load swiped IDs from SwiftData for filtering
    func loadSwipedIDs(context: ModelContext) async {
        let descriptor = FetchDescriptor<SwipedItem>()
        
        do {
            let swipedItems = try context.fetch(descriptor)
            await MainActor.run {
                self.swipedIDs = Set(swipedItems.map { $0.uniqueID })
            }
        } catch {
            #if DEBUG
            print("Error loading swiped IDs: \(error)")
            #endif
        }
    }
    
    /// Load more content from the API
    func loadContent() async {
        guard !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let newItems = try await mediaService.fetchContent(
                for: selectedMethod,
                contentType: contentTypeFilter,
                genre: selectedGenre,
                page: currentPage,
                sort: selectedSort
            )
            
            // Filter out already swiped items
            let filteredItems = filterSwipedItems(newItems)
            
            await MainActor.run {
                if filteredItems.isEmpty && newItems.isEmpty {
                    hasReachedEnd = true
                } else {
                    mediaItems.append(contentsOf: filteredItems)
                    currentPage += 1
                    
                    // If we filtered too many items, load more
                    if filteredItems.count < 5 && !hasReachedEnd {
                        Task { await loadContent() }
                    }
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    /// Reset and reload content (when changing discovery method)
    func resetAndLoadContent() async {
        await MainActor.run {
            mediaItems = []
            currentPage = 1
            hasReachedEnd = false
        }
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
    
    /// Handle swipe right (mark as seen)
    @discardableResult
    func swipeRight(item: MediaItem, context: ModelContext) -> SwipedItem {
        // Add to undo stack
        addToUndoStack(item: item, direction: .seen)
        
        // Add to swiped IDs
        swipedIDs.insert(item.uniqueID)
        
        // Create SwipedItem record with full details
        let swipedItem = SwipedItem(from: item, direction: .seen)
        
        // Store which platform the user was browsing (only for streaming methods)
        if selectedMethod.watchProviderID != nil {
            swipedItem.sourcePlatform = selectedMethod.rawValue
        }
        
        context.insert(swipedItem)
        
        // Save context
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Error saving swipe right: \(error)")
            #endif
        }
        
        // Remove from queue
        removeFromQueue(item: item)
        
        // Trigger haptic
        HapticManager.seen()
        
        return swipedItem
    }
    
    /// Handle swipe left (skip)
    func swipeLeft(item: MediaItem, context: ModelContext) {
        // Add to undo stack
        addToUndoStack(item: item, direction: .skipped)
        
        // Add to swiped IDs
        swipedIDs.insert(item.uniqueID)
        
        // Create SwipedItem record
        let swipedItem = SwipedItem(from: item, direction: .skipped)
        
        // Store which platform the user was browsing (only for streaming methods)
        if selectedMethod.watchProviderID != nil {
            swipedItem.sourcePlatform = selectedMethod.rawValue
        }
        
        context.insert(swipedItem)
        
        // Save context
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Error saving swipe left: \(error)")
            #endif
        }
        
        // Remove from queue
        removeFromQueue(item: item)
        
        // Trigger haptic
        HapticManager.skip()
    }
    
    /// Undo the last swipe action
    func undoLastSwipe(context: ModelContext) {
        guard let lastSwipe = undoStack.popLast() else { return }
        
        let item = lastSwipe.item
        
        // Capture uniqueID for predicate (required by #Predicate macro)
        let itemUniqueID = item.uniqueID
        
        // Remove from swiped IDs
        swipedIDs.remove(itemUniqueID)
        
        // Delete the SwipedItem record
        let swipedDescriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate<SwipedItem> { swipedItem in
                swipedItem.uniqueID == itemUniqueID
            }
        )
        
        do {
            let swipedItems = try context.fetch(swipedDescriptor)
            for swipedItem in swipedItems {
                context.delete(swipedItem)
            }
            
            try context.save()
            
            // Add item back to the front of the queue
            mediaItems.insert(item, at: 0)
            
            // Trigger haptic
            HapticManager.undo()
            
        } catch {
            #if DEBUG
            print("Error undoing swipe: \(error)")
            #endif
        }
    }
    
    // MARK: - Undo Stack Management
    
    private func addToUndoStack(item: MediaItem, direction: SwipedItem.SwipeDirection) {
        undoStack.append((item: item, direction: direction))
        
        // Keep stack size limited
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
        
        for item in itemsToPrefetch {
            guard !prefetchedImages.contains(item.uniqueID) else { continue }
            guard let posterURL = item.posterURL else { continue }
            
            prefetchedImages.insert(item.uniqueID)
            
            // Build w185 thumbnail URL (same as SeenItemCard) so Already Seen list can use cache
            let thumbnailURL = item.posterPath.flatMap { path in
                URL(string: "https://image.tmdb.org/t/p/w185\(path)")
            }
            
            // Start image downloads in background (poster for swipe card, thumbnail for Already Seen)
            Task.detached(priority: .background) {
                do {
                    let (_, _) = try await URLSession.shared.data(from: posterURL)
                } catch {}
                if let thumbURL = thumbnailURL {
                    do {
                        let (_, _) = try await URLSession.shared.data(from: thumbURL)
                    } catch {}
                }
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
    
    /// Reset all swiped items (clear history)
    func resetAllSwipedItems(context: ModelContext) {
        // Delete all SwipedItem records
        do {
            try context.delete(model: SwipedItem.self)
            try context.save()
            swipedIDs.removeAll()
            Task { await resetAndLoadContent() }
        } catch {
            #if DEBUG
            print("Error resetting swiped items: \(error)")
            #endif
        }
    }
    
    /// Reset only skipped items (keep seen items)
    func resetSkippedItems(context: ModelContext) {
        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate { $0.swipeDirection == "skipped" }
        )
        
        do {
            let skippedItems = try context.fetch(descriptor)
            for item in skippedItems {
                swipedIDs.remove(item.uniqueID)
                context.delete(item)
            }
            try context.save()
            Task { await resetAndLoadContent() }
        } catch {
            #if DEBUG
            print("Error resetting skipped items: \(error)")
            #endif
        }
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
        UserDefaults.standard.set(selectedMethod.rawValue, forKey: "selectedDiscoveryMethod")
    }
    
    /// Load selected discovery method from UserDefaults
    private func loadSelectedMethod() {
        if let savedMethod = UserDefaults.standard.string(forKey: "selectedDiscoveryMethod"),
           let method = DiscoveryMethod(rawValue: savedMethod) {
            selectedMethod = method
        }
    }
}
