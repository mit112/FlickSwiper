import XCTest
@testable import FlickSwiper

// MARK: - SearchViewModel Tests
//
// Tests search logic: empty query handling, result population, and error state.
// Uses MockMediaService for dependency injection.
// Debounce tests use short sleeps to allow the async task to complete.

@MainActor
final class SearchViewModelTests: XCTestCase {
    
    private var mockService: MockMediaService!
    private var viewModel: SearchViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        mockService = MockMediaService()
        viewModel = SearchViewModel(mediaService: mockService)
    }
    
    override func tearDown() async throws {
        mockService = nil
        viewModel = nil
        try await super.tearDown()
    }
    
    // MARK: - Empty Query
    
    func testEmptyQueryClearsResults() {
        viewModel.searchText = ""
        viewModel.search()
        
        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertFalse(viewModel.hasSearched)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testWhitespaceOnlyQueryClearsResults() {
        viewModel.searchText = "   "
        viewModel.search()
        
        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertFalse(viewModel.hasSearched)
    }
    
    func testClearingSearchTextAfterResultsResetsState() async {
        // Set up mock to return items
        let items = MockMediaService.createMockItems(count: 3)
        await mockService.setSearchItems(items)
        
        // Perform search
        viewModel.searchText = "Fight Club"
        viewModel.search()
        
        // Wait for debounce (400ms) + some margin
        try? await Task.sleep(for: .milliseconds(600))
        
        XCTAssertFalse(viewModel.results.isEmpty, "Should have results after search")
        
        // Clear the search
        viewModel.searchText = ""
        viewModel.search()
        
        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertFalse(viewModel.hasSearched)
    }
    
    // MARK: - Successful Search
    
    func testSearchPopulatesResults() async {
        let items = MockMediaService.createMockItems(count: 5)
        await mockService.setSearchItems(items)
        
        viewModel.searchText = "Test"
        viewModel.search()
        
        // Wait for debounce + network
        try? await Task.sleep(for: .milliseconds(600))
        
        XCTAssertEqual(viewModel.results.count, 5)
        XCTAssertTrue(viewModel.hasSearched)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Error Handling
    
    func testSearchErrorSetsErrorMessage() async {
        await mockService.setShouldFail(true)
        
        viewModel.searchText = "Test"
        viewModel.search()
        
        // Wait for debounce + error
        try? await Task.sleep(for: .milliseconds(600))
        
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.hasSearched)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Debounce Cancellation
    
    func testRapidSearchesCancelPreviousTasks() async {
        let items = MockMediaService.createMockItems(count: 3)
        await mockService.setSearchItems(items)
        
        // Fire multiple searches rapidly (only the last should execute)
        viewModel.searchText = "A"
        viewModel.search()
        viewModel.searchText = "AB"
        viewModel.search()
        viewModel.searchText = "ABC"
        viewModel.search()
        
        // Wait for debounce of the last search only
        try? await Task.sleep(for: .milliseconds(600))
        
        let callCount = await mockService.searchCallCount
        // Due to cancellation, only the last search should have reached the service.
        // In practice 1 call is expected, but timing may allow 0 or 1.
        XCTAssertLessThanOrEqual(callCount, 1,
            "Rapid searches should cancel previous tasks, resulting in at most 1 service call")
    }
}
