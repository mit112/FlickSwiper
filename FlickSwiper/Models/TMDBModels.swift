import Foundation

// MARK: - Movie Response from TMDB

nonisolated struct TMDBMovie: Codable, Identifiable, Sendable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let releaseDate: String?
    let voteAverage: Double?
    let genreIds: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
    }
}

// MARK: - TV Show Response from TMDB

nonisolated struct TMDBTVShow: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let genreIds: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case posterPath = "poster_path"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
    }
}

// MARK: - Paginated Response Wrapper

nonisolated struct TMDBResponse<T: Codable & Sendable>: Codable, Sendable {
    let page: Int
    let results: [T]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

// MARK: - Trending Response (has media_type field)

nonisolated struct TMDBTrendingItem: Codable, Identifiable, Sendable {
    let id: Int
    let mediaType: String
    let title: String?       // For movies
    let name: String?        // For TV shows
    let overview: String?
    let posterPath: String?
    let releaseDate: String? // For movies
    let firstAirDate: String? // For TV shows
    let voteAverage: Double?
    let genreIds: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case mediaType = "media_type"
        case title
        case name
        case overview
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
    }
    
    nonisolated var displayTitle: String {
        title ?? name ?? "Unknown"
    }
    
    nonisolated var displayReleaseDate: String? {
        releaseDate ?? firstAirDate
    }
}
