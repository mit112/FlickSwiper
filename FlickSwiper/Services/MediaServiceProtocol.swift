import Foundation

/// Protocol for media fetching services.
/// Enables dependency injection for testability.
/// Mock implementation is in FlickSwiperTests/MockMediaService.swift.
protocol MediaServiceProtocol: Sendable {
    /// Fetch content based on the selected discovery method
    func fetchContent(
        for method: DiscoveryMethod,
        contentType: ContentTypeFilter,
        genre: Genre?,
        page: Int,
        sort: StreamingSortOption,
        yearMin: Int?,
        yearMax: Int?
    ) async throws -> [MediaItem]

    /// Search for movies and TV shows
    func searchMulti(query: String, page: Int) async throws -> [MediaItem]
}
