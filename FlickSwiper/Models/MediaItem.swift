import Foundation

// MARK: - Unified Media Item for UI

/// A unified type representing both movies and TV shows for use in the UI
struct MediaItem: Identifiable, Sendable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let releaseDate: String?
    let rating: Double?
    let mediaType: MediaType
    var genreIds: [Int] = []
    
    enum MediaType: String, Codable, Hashable {
        case movie
        case tvShow
        
        var displayName: String {
            switch self {
            case .movie: return "Movie"
            case .tvShow: return "TV Show"
            }
        }
    }
    
    /// Unique identifier combining media type and ID to avoid collisions
    var uniqueID: String {
        "\(mediaType.rawValue)_\(id)"
    }
    
    /// Full URL for the poster image
    var posterURL: URL? {
        guard let posterPath = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }

    /// Thumbnail URL for list/grid (w185)
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
}

// MARK: - Identity

/// Identity is based on `uniqueID` (mediaType + TMDB ID), matching how the app
/// deduplicates items across discovery, filtering, and SwiftData persistence.
extension MediaItem: Equatable {
    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id && lhs.mediaType == rhs.mediaType
    }
}

extension MediaItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(mediaType)
    }
}

// MARK: - Conversion Extensions

extension MediaItem {
    /// Create MediaItem from TMDB Movie response
    nonisolated init(from movie: TMDBMovie) {
        self.id = movie.id
        self.title = movie.title
        self.overview = movie.overview ?? ""
        self.posterPath = movie.posterPath
        self.releaseDate = movie.releaseDate
        self.rating = movie.voteAverage
        self.mediaType = .movie
        self.genreIds = movie.genreIds ?? []
    }
    
    /// Create MediaItem from TMDB TV Show response
    nonisolated init(from tvShow: TMDBTVShow) {
        self.id = tvShow.id
        self.title = tvShow.name
        self.overview = tvShow.overview ?? ""
        self.posterPath = tvShow.posterPath
        self.releaseDate = tvShow.firstAirDate
        self.rating = tvShow.voteAverage
        self.mediaType = .tvShow
        self.genreIds = tvShow.genreIds ?? []
    }
    
    /// Create MediaItem from TMDB Trending Item response
    nonisolated init(from trending: TMDBTrendingItem) {
        self.id = trending.id
        self.title = trending.displayTitle
        self.overview = trending.overview ?? ""
        self.posterPath = trending.posterPath
        self.releaseDate = trending.displayReleaseDate
        self.rating = trending.voteAverage
        self.mediaType = trending.mediaType == "movie" ? .movie : .tvShow
        self.genreIds = trending.genreIds ?? []
    }
}
