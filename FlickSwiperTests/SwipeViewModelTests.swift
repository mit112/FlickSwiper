import XCTest
import SwiftData
@testable import FlickSwiper

// MARK: - SwipeViewModel Tests
//
// Tests the core swipe logic: undo stack, filtering, error handling,
// and SwiftData persistence. Uses MockMediaService and an in-memory
// SwiftData container to avoid network calls and disk I/O.

@MainActor
final class SwipeViewModelTests: XCTestCase {
    
    private var container: ModelContainer!
    private var context: ModelContext!
    private var mockService: MockMediaService!
    private var viewModel: SwipeViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        
        let schema = Schema([SwipedItem.self, UserList.self, ListEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        
        mockService = MockMediaService()
        viewModel = SwipeViewModel(mediaService: mockService)
    }
    
    override func tearDown() async throws {
        container = nil
        context = nil
        mockService = nil
        viewModel = nil
        try await super.tearDown()
    }
    
    // MARK: - Visible Cards
    
    func testVisibleCardsReturnsMaxThree() async {
        await mockService.setMockItems(MockMediaService.createMockItems(count: 10))
        await viewModel.loadInitialContent(context: context)
        
        XCTAssertEqual(viewModel.visibleCards.count, 3)
    }
    
    func testVisibleCardsReturnsFewerIfQueueIsSmall() async {
        // Return 2 items on first fetch, then empty — prevents auto-pagination
        // from accumulating duplicates (loadContent fetches up to 5 pages if < 5 items)
        await mockService.setMockItems(MockMediaService.createMockItems(count: 2))
        await mockService.setReturnItemsOnlyOnFirstFetch(true)
        await viewModel.loadInitialContent(context: context)
        
        XCTAssertEqual(viewModel.visibleCards.count, 2)
    }
    
    func testCurrentCardIsFirstItem() async {
        let items = MockMediaService.createMockItems(count: 5)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        XCTAssertEqual(viewModel.currentCard?.id, items.first?.id)
    }
    
    // MARK: - Swipe Right (Seen)
    
    func testSwipeRightRemovesFromQueue() async {
        let items = MockMediaService.createMockItems(count: 5)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        let firstItem = viewModel.mediaItems[0]
        let initialCount = viewModel.mediaItems.count
        
        viewModel.swipeRight(item: firstItem, context: context)
        
        XCTAssertEqual(viewModel.mediaItems.count, initialCount - 1)
        XCTAssertFalse(viewModel.mediaItems.contains(where: { $0.id == firstItem.id }))
    }
    
    func testSwipeRightPersistsToSwiftData() async {
        let items = MockMediaService.createMockItems(count: 3)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        let firstItem = viewModel.mediaItems[0]
        viewModel.swipeRight(item: firstItem, context: context)
        
        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate { $0.swipeDirection == "seen" }
        )
        let saved = try? context.fetch(descriptor)
        
        XCTAssertEqual(saved?.count, 1)
        XCTAssertEqual(saved?.first?.title, firstItem.title)
    }
    
    func testSwipeRightReturnsSwipedItem() async {
        let items = MockMediaService.createMockItems(count: 3)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        let firstItem = viewModel.mediaItems[0]
        let result = viewModel.swipeRight(item: firstItem, context: context)
        
        XCTAssertEqual(result.mediaID, firstItem.id)
        XCTAssertTrue(result.isSeen)
    }
    
    // MARK: - Swipe Left (Skip)
    
    func testSwipeLeftRemovesFromQueue() async {
        let items = MockMediaService.createMockItems(count: 5)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        let firstItem = viewModel.mediaItems[0]
        viewModel.swipeLeft(item: firstItem, context: context)
        
        XCTAssertFalse(viewModel.mediaItems.contains(where: { $0.id == firstItem.id }))
    }
    
    func testSwipeLeftPersistsAsSkipped() async {
        let items = MockMediaService.createMockItems(count: 3)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        let firstItem = viewModel.mediaItems[0]
        viewModel.swipeLeft(item: firstItem, context: context)
        
        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate { $0.swipeDirection == "skipped" }
        )
        let saved = try? context.fetch(descriptor)
        
        XCTAssertEqual(saved?.count, 1)
    }
    
    // MARK: - Undo
    
    func testUndoRestoresItemToFrontOfQueue() async {
        let items = MockMediaService.createMockItems(count: 5)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        let firstItem = viewModel.mediaItems[0]
        viewModel.swipeRight(item: firstItem, context: context)
        
        XCTAssertTrue(viewModel.canUndo)
        
        viewModel.undoLastSwipe(context: context)
        
        XCTAssertEqual(viewModel.mediaItems.first?.id, firstItem.id,
                       "Undone item should be back at the front of the queue")
    }
    
    func testUndoDeletesSwipedItemFromStore() async {
        let items = MockMediaService.createMockItems(count: 3)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        let firstItem = viewModel.mediaItems[0]
        viewModel.swipeRight(item: firstItem, context: context)
        viewModel.undoLastSwipe(context: context)
        
        let descriptor = FetchDescriptor<SwipedItem>()
        let saved = try? context.fetch(descriptor)
        
        XCTAssertEqual(saved?.count, 0,
                       "Undo should delete the persisted SwipedItem record")
    }
    
    func testCanUndoIsFalseWhenStackIsEmpty() {
        XCTAssertFalse(viewModel.canUndo)
    }
    
    func testUndoStackLimitsToMaxSize() async {
        // The max undo stack size is 10
        let items = MockMediaService.createMockItems(count: 15)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        // Swipe 12 items
        for i in 0..<12 {
            viewModel.swipeLeft(item: items[i], context: context)
        }
        
        // Undo should work 10 times max (stack capped at 10)
        var undoCount = 0
        while viewModel.canUndo {
            viewModel.undoLastSwipe(context: context)
            undoCount += 1
        }
        
        XCTAssertEqual(undoCount, 10)
    }
    
    func testClearUndoStackResetsCanUndo() async {
        let items = MockMediaService.createMockItems(count: 3)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        viewModel.swipeLeft(item: items[0], context: context)
        XCTAssertTrue(viewModel.canUndo)
        
        viewModel.clearUndoStack()
        XCTAssertFalse(viewModel.canUndo)
    }
    
    // MARK: - Error Handling
    
    func testLoadContentSetsErrorMessageOnFailure() async {
        await mockService.setShouldFail(true)
        
        await viewModel.loadContent()
        
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testLoadContentClearsErrorOnRetry() async {
        // First load fails
        await mockService.setShouldFail(true)
        await viewModel.loadContent()
        XCTAssertNotNil(viewModel.errorMessage)
        
        // Second load succeeds
        await mockService.setShouldFail(false)
        await mockService.setMockItems(MockMediaService.createMockItems(count: 5))
        await viewModel.loadContent()
        
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Source Platform Tracking
    
    func testSwipeRightSetsSourcePlatformForStreamingMethod() async {
        let items = MockMediaService.createMockItems(count: 3)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        viewModel.selectedMethod = .netflix
        // Wait for debounce to settle
        try? await Task.sleep(for: .milliseconds(400))
        
        // Re-load items since method change triggers reload
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        guard let firstItem = viewModel.mediaItems.first else {
            XCTFail("No items in queue")
            return
        }
        
        let result = viewModel.swipeRight(item: firstItem, context: context)
        XCTAssertEqual(result.sourcePlatform, "Netflix")
    }
    
    func testSwipeRightNoSourcePlatformForGeneralMethod() async {
        let items = MockMediaService.createMockItems(count: 3)
        await mockService.setMockItems(items)
        
        viewModel.selectedMethod = .popular
        await viewModel.loadInitialContent(context: context)
        
        let firstItem = viewModel.mediaItems[0]
        let result = viewModel.swipeRight(item: firstItem, context: context)
        
        XCTAssertNil(result.sourcePlatform)
    }
    
    // MARK: - Watchlist (Save for Later)
    
    func testWatchlistRemovesFromQueue() async {
        let items = MockMediaService.createMockItems(count: 5)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        let firstItem = viewModel.mediaItems[0]
        
        // Mimic SwipeView.saveToWatchlist: add to undo stack, persist, remove from stack
        viewModel.addToUndoStack(item: firstItem, direction: .watchlist)
        let swipedItem = SwipedItem(from: firstItem, direction: .watchlist)
        context.insert(swipedItem)
        try? context.save()
        viewModel.removeCardFromStack(item: firstItem)
        
        XCTAssertFalse(viewModel.mediaItems.contains(where: { $0.id == firstItem.id }),
                       "Watchlisted item should be removed from the card queue")
    }
    
    func testWatchlistPersistsWithCorrectDirection() async {
        let items = MockMediaService.createMockItems(count: 3)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        let firstItem = viewModel.mediaItems[0]
        
        let swipedItem = SwipedItem(from: firstItem, direction: .watchlist)
        context.insert(swipedItem)
        try? context.save()
        viewModel.removeCardFromStack(item: firstItem)
        
        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate { $0.swipeDirection == "watchlist" }
        )
        let saved = try? context.fetch(descriptor)
        
        XCTAssertEqual(saved?.count, 1)
        XCTAssertTrue(saved?.first?.isWatchlist == true)
        XCTAssertEqual(saved?.first?.title, firstItem.title)
    }
    
    func testWatchlistItemDoesNotReappearInDiscovery() async {
        let items = MockMediaService.createMockItems(count: 5)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        let firstItem = viewModel.mediaItems[0]
        let uniqueID = firstItem.uniqueID
        
        // Save to watchlist via the ViewModel path
        viewModel.addToUndoStack(item: firstItem, direction: .watchlist)
        let swipedItem = SwipedItem(from: firstItem, direction: .watchlist)
        context.insert(swipedItem)
        try? context.save()
        viewModel.removeCardFromStack(item: firstItem)
        
        // Reload swiped IDs (as would happen on next app launch / tab switch)
        viewModel.loadSwipedIDs(context: context)
        
        // Re-fetch same items — the watchlisted one should be filtered out
        await mockService.setMockItems(items)
        await viewModel.resetAndLoadContent()
        
        XCTAssertFalse(viewModel.mediaItems.contains(where: { $0.uniqueID == uniqueID }),
                       "Watchlisted items should be filtered out of discovery")
    }
    
    func testUndoWatchlistRestoresCard() async {
        let items = MockMediaService.createMockItems(count: 5)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        let firstItem = viewModel.mediaItems[0]
        
        // Save to watchlist
        viewModel.addToUndoStack(item: firstItem, direction: .watchlist)
        let swipedItem = SwipedItem(from: firstItem, direction: .watchlist)
        context.insert(swipedItem)
        try? context.save()
        viewModel.removeCardFromStack(item: firstItem)
        
        XCTAssertTrue(viewModel.canUndo)
        
        // Undo should restore the card and delete the persisted record
        viewModel.undoLastSwipe(context: context)
        
        XCTAssertEqual(viewModel.mediaItems.first?.id, firstItem.id,
                       "Undone watchlist item should be back at the front of the queue")
        
        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate { $0.swipeDirection == "watchlist" }
        )
        let remaining = try? context.fetch(descriptor)
        XCTAssertEqual(remaining?.count, 0,
                       "Undo should delete the watchlist SwipedItem record")
    }
    
    // MARK: - RemoveCardFromStack
    
    func testRemoveCardFromStackAddsToSwipedIDs() async {
        let items = MockMediaService.createMockItems(count: 5)
        await mockService.setMockItems(items)
        await viewModel.loadInitialContent(context: context)
        
        let firstItem = viewModel.mediaItems[0]
        viewModel.removeCardFromStack(item: firstItem)
        
        XCTAssertFalse(viewModel.mediaItems.contains(where: { $0.uniqueID == firstItem.uniqueID }))
    }
}
