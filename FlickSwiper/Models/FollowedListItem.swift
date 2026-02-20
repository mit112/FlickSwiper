import Foundation
import SwiftData

/// A single item within a followed list, cached locally from Firestore.
///
/// These are display-only records — they don't need to exist in the user's
/// `SwipedItem` database. The user can tap an item to add it to their own
/// library, but that creates a separate `SwipedItem` record.
///
/// Linked to `FollowedList` by `followedListID` (Firestore doc ID),
/// using the same UUID-based join pattern as `ListEntry`.
@Model
final class FollowedListItem {
    var id: UUID
    
    /// References `FollowedList.firestoreDocID`.
    var followedListID: String
    
    /// TMDB ID of the movie or TV show.
    var tmdbID: Int
    
    /// "movie" or "tvShow" — matches `MediaItem.MediaType.rawValue`.
    var mediaType: String
    
    /// Cached title from the published list (denormalized from TMDB).
    var title: String
    
    /// Cached poster path for display. Construct full URL with TMDB image base.
    var posterPath: String?
    
    /// Preserves the owner's ordering of items in the list.
    var sortOrder: Int
    
    init(
        followedListID: String,
        tmdbID: Int,
        mediaType: String,
        title: String,
        posterPath: String?,
        sortOrder: Int
    ) {
        self.id = UUID()
        self.followedListID = followedListID
        self.tmdbID = tmdbID
        self.mediaType = mediaType
        self.title = title
        self.posterPath = posterPath
        self.sortOrder = sortOrder
    }
    
    // MARK: - Computed Properties
    
    /// Composite unique ID matching the format used by `SwipedItem` and `MediaItem`.
    /// Useful for checking if this item already exists in the user's local library.
    var uniqueID: String {
        "\(mediaType)_\(tmdbID)"
    }
    
    /// Full poster URL (w500) for detail views.
    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    /// Thumbnail URL (w185) for grid/list views.
    var thumbnailURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(posterPath)")
    }
}
