import Foundation
@testable import FlickSwiper

// MARK: - Mock Service for Testing
//
// Lives in the test target (not production code) so it doesn't ship in the release binary.

/// Mock implementation of MediaServiceProtocol for unit testing
actor MockMediaService: MediaServiceProtocol {
    /// Items to return from fetch calls
    var mockItems: [MediaItem] = []
    
    /// Whether fetch should throw an error
    var shouldFail: Bool = false
    
    /// Error to throw when shouldFail is true
    var errorToThrow: Error = TMDBError.invalidResponse
    
    /// When true, fetchContent returns items only on the first call, then empty.
    /// Simulates reaching the end of available content after one page.
    var returnItemsOnlyOnFirstFetch: Bool = false
    
    /// Track number of fetch calls for testing
    var fetchCallCount: Int = 0
    
    /// Track number of search calls for testing
    var searchCallCount: Int = 0
    
    /// Last parameters passed to fetchContent
    var lastFetchParameters: (method: DiscoveryMethod, contentType: ContentTypeFilter, genre: Genre?, page: Int, sort: StreamingSortOption, yearMin: Int?, yearMax: Int?)?
    
    /// Last query passed to searchMulti
    var lastSearchQuery: String?
    
    /// Items to return from search calls (separate from fetch)
    var mockSearchItems: [MediaItem] = []

    func fetchContent(
        for method: DiscoveryMethod,
        contentType: ContentTypeFilter,
        genre: Genre?,
        page: Int,
        sort: StreamingSortOption = .popular,
        yearMin: Int? = nil,
        yearMax: Int? = nil
    ) async throws -> [MediaItem] {
        fetchCallCount += 1
        lastFetchParameters = (method, contentType, genre, page, sort, yearMin, yearMax)

        if shouldFail {
            throw errorToThrow
        }

        if returnItemsOnlyOnFirstFetch && fetchCallCount > 1 {
            return []
        }
        return mockItems
    }

    func searchMulti(query: String, page: Int) async throws -> [MediaItem] {
        searchCallCount += 1
        lastSearchQuery = query
        
        if shouldFail {
            throw errorToThrow
        }
        
        return mockSearchItems
    }
    
    // MARK: - Test Helpers
    
    /// Reset mock state
    func reset() {
        mockItems = []
        mockSearchItems = []
        shouldFail = false
        returnItemsOnlyOnFirstFetch = false
        errorToThrow = TMDBError.invalidResponse
        fetchCallCount = 0
        searchCallCount = 0
        lastFetchParameters = nil
        lastSearchQuery = nil
    }
    
    /// Create mock media items for testing
    static func createMockItems(count: Int) -> [MediaItem] {
        (0..<count).map { index in
            MediaItem(
                id: index,
                title: "Test Movie \(index)",
                overview: "Test overview for movie \(index)",
                posterPath: "/test\(index).jpg",
                releaseDate: "2024-01-01",
                rating: Double(index % 10) + 1.0,
                mediaType: index % 2 == 0 ? .movie : .tvShow
            )
        }
    }
    
    // MARK: - Actor-Safe Setters
    // (Called from @MainActor test methods — these run on the actor's context)
    
    func setMockItems(_ items: [MediaItem]) {
        self.mockItems = items
    }
    
    func setShouldFail(_ fail: Bool) {
        self.shouldFail = fail
    }
    
    func setSearchItems(_ items: [MediaItem]) {
        self.mockSearchItems = items
    }
    
    func setReturnItemsOnlyOnFirstFetch(_ value: Bool) {
        self.returnItemsOnlyOnFirstFetch = value
    }
}
