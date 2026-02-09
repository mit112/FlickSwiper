import Foundation
import SwiftData

/// Tracks ALL swiped items (both "seen" and "skipped")
/// Used for filtering to prevent duplicates from appearing again
/// Also stores full details for "seen" items to display in the Already Seen list
@Model
final class SwipedItem: Identifiable {
    /// SwiftData models use persistentModelID for identity, but we expose uniqueID for convenience
    var id: String { uniqueID }
    /// Unique identifier combining media type and TMDB ID
    @Attribute(.unique) var uniqueID: String
    
    /// The TMDB ID of the media item
    var mediaID: Int
    
    /// Type of media: "movie" or "tvShow"
    var mediaType: String
    
    /// Direction of swipe: "seen" or "skipped"
    var swipeDirection: String
    
    /// When the item was swiped
    var dateSwiped: Date
    
    // MARK: - Full Media Details (for seen items display)
    // Note: Default values allow migration from older schema versions
    
    /// Title of the movie or TV show
    var title: String = ""
    
    /// Plot overview/description
    var overview: String = ""
    
    /// Path to poster image (to construct full URL)
    var posterPath: String?
    
    /// Release date (movie) or first air date (TV show)
    var releaseDate: String?
    
    /// TMDB rating (0-10)
    var rating: Double?
    
    // MARK: - V2 Fields (optional for lightweight migration)
    
    /// User's personal rating (1-5 stars), nil = unrated
    var personalRating: Int?
    
    /// Comma-separated genre IDs from TMDB, e.g. "28,12,878"
    var genreIDsString: String?
    
    /// Which streaming platform the user was browsing when they swiped, e.g. "Netflix"
    var sourcePlatform: String?
    
    // MARK: - Initialization
    
    init(mediaID: Int, mediaType: MediaItem.MediaType, swipeDirection: SwipeDirection,
         title: String, overview: String, posterPath: String?, releaseDate: String?, rating: Double?,
         genreIds: [Int] = []) {
        self.uniqueID = "\(mediaType.rawValue)_\(mediaID)"
        self.mediaID = mediaID
        self.mediaType = mediaType.rawValue
        self.swipeDirection = swipeDirection.rawValue
        self.dateSwiped = Date()
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.releaseDate = releaseDate
        self.rating = rating
        self.personalRating = nil
        self.genreIDsString = genreIds.isEmpty ? nil : genreIds.map(String.init).joined(separator: ",")
        self.sourcePlatform = nil
    }
    
    convenience init(from mediaItem: MediaItem, direction: SwipeDirection) {
        self.init(
            mediaID: mediaItem.id,
            mediaType: mediaItem.mediaType,
            swipeDirection: direction,
            title: mediaItem.title,
            overview: mediaItem.overview,
            posterPath: mediaItem.posterPath,
            releaseDate: mediaItem.releaseDate,
            rating: mediaItem.rating,
            genreIds: mediaItem.genreIds
        )
    }
    
    // MARK: - Swipe Direction
    
    enum SwipeDirection: String {
        case seen
        case skipped
        case watchlist
    }
    
    /// Whether this item was marked as "seen"
    var isSeen: Bool {
        swipeDirection == SwipeDirection.seen.rawValue
    }
    
    /// Whether this item is in the watchlist
    var isWatchlist: Bool {
        swipeDirection == SwipeDirection.watchlist.rawValue
    }
    
    // MARK: - Computed Properties (for SeenListView compatibility)
    
    /// Full URL for the poster image (large, for detail view)
    var posterURL: URL? {
        guard let posterPath = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    /// Thumbnail URL for the poster image (smaller, for grid view)
    var thumbnailURL: URL? {
        guard let posterPath = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(posterPath)")
    }
    
    /// Formatted release year
    var releaseYear: String? {
        guard let releaseDate = releaseDate, !releaseDate.isEmpty else { return nil }
        return String(releaseDate.prefix(4))
    }
    
    /// Formatted rating string
    var ratingText: String? {
        guard let rating = rating, rating > 0 else { return nil }
        return String(format: "%.1f", rating)
    }
    
    /// Media type as enum
    var mediaTypeEnum: MediaItem.MediaType {
        MediaItem.MediaType(rawValue: mediaType) ?? .movie
    }
    
    // MARK: - Genre Helpers
    
    /// Parsed genre IDs from the stored comma-separated string
    var genreIDs: [Int] {
        guard let string = genreIDsString else { return [] }
        return string.split(separator: ",").compactMap { Int($0) }
    }
    
    /// Convenience get/set for personalRating
    var ratingStars: Int? {
        get { personalRating }
        set { personalRating = newValue }
    }
}
