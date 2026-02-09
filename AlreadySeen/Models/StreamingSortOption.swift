import Foundation

/// Sort options for streaming service discovery (movies and TV)
enum StreamingSortOption: String, CaseIterable, Identifiable {
    case popular = "Popular"
    case topRated = "Top Rated"
    case newest = "Newest"
    case oldest = "Oldest"
    case titleAZ = "A → Z"
    case titleZA = "Z → A"

    var id: String { rawValue }

    /// Sort parameter for TMDB movie discover endpoint
    var movieSortParam: String {
        switch self {
        case .popular: return "popularity.desc"
        case .topRated: return "vote_average.desc"
        case .newest: return "primary_release_date.desc"
        case .oldest: return "primary_release_date.asc"
        case .titleAZ: return "title.asc"
        case .titleZA: return "title.desc"
        }
    }

    /// Sort parameter for TMDB TV discover endpoint
    var tvSortParam: String {
        switch self {
        case .popular: return "popularity.desc"
        case .topRated: return "vote_average.desc"
        case .newest: return "first_air_date.desc"
        case .oldest: return "first_air_date.asc"
        case .titleAZ: return "name.asc"
        case .titleZA: return "name.desc"
        }
    }

    var icon: String {
        switch self {
        case .popular: return "flame"
        case .topRated: return "star"
        case .newest: return "arrow.down"
        case .oldest: return "arrow.up"
        case .titleAZ: return "textformat.abc"
        case .titleZA: return "textformat.abc"
        }
    }
}
