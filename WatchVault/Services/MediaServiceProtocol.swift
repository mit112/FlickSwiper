import Foundation

/// Protocol for media fetching services
/// Enables dependency injection for testability
protocol MediaServiceProtocol: Sendable {
    /// Fetch content based on the selected discovery method
    func fetchContent(
        for method: DiscoveryMethod,
        contentType: ContentTypeFilter,
        genre: Genre?,
        page: Int,
        sort: StreamingSortOption
    ) async throws -> [MediaItem]

    /// Search for movies and TV shows
    func searchMulti(query: String, page: Int) async throws -> [MediaItem]
}

// MARK: - Mock Service for Testing

/// Mock implementation of MediaServiceProtocol for unit testing
actor MockMediaService: MediaServiceProtocol {
    /// Items to return from fetch calls
    var mockItems: [MediaItem] = []
    
    /// Whether fetch should throw an error
    var shouldFail: Bool = false
    
    /// Error to throw when shouldFail is true
    var errorToThrow: Error = TMDBError.invalidResponse
    
    /// Track number of fetch calls for testing
    var fetchCallCount: Int = 0
    
    /// Last parameters passed to fetchContent
    var lastFetchParameters: (method: DiscoveryMethod, contentType: ContentTypeFilter, genre: Genre?, page: Int, sort: StreamingSortOption)?

    func fetchContent(
        for method: DiscoveryMethod,
        contentType: ContentTypeFilter,
        genre: Genre?,
        page: Int,
        sort: StreamingSortOption = .popular
    ) async throws -> [MediaItem] {
        fetchCallCount += 1
        lastFetchParameters = (method, contentType, genre, page, sort)

        if shouldFail {
            throw errorToThrow
        }

        return mockItems
    }

    func searchMulti(query: String, page: Int) async throws -> [MediaItem] {
        return []
    }
    
    // MARK: - Test Helpers
    
    /// Reset mock state
    func reset() {
        mockItems = []
        shouldFail = false
        errorToThrow = TMDBError.invalidResponse
        fetchCallCount = 0
        lastFetchParameters = nil
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
}
