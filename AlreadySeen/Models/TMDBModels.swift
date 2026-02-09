import Foundation

// MARK: - Movie Response from TMDB

struct TMDBMovie: Codable, Identifiable {
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

struct TMDBTVShow: Codable, Identifiable {
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

struct TMDBResponse<T: Codable>: Codable {
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

struct TMDBTrendingItem: Codable, Identifiable {
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
    
    var displayTitle: String {
        title ?? name ?? "Unknown"
    }
    
    var displayReleaseDate: String? {
        releaseDate ?? firstAirDate
    }
}
