import Foundation

/// Discovery methods for browsing movies and TV shows
enum DiscoveryMethod: String, CaseIterable, Identifiable, Codable, Sendable {
    // General discovery
    case topRated = "Top Rated"
    case popular = "Popular"
    case trending = "Trending"
    case nowPlaying = "Now Playing"
    case upcoming = "Upcoming"
    
    // Premium streaming services
    case netflix = "Netflix"
    case amazonPrime = "Prime Video"
    case disneyPlus = "Disney+"
    case max = "Max"  // Formerly HBO Max
    case appleTVPlus = "Apple TV+"
    case hulu = "Hulu"
    case paramountPlus = "Paramount+"
    case peacock = "Peacock"
    
    // Free streaming
    case tubi = "Tubi (Free)"
    case plutoTV = "Pluto TV (Free)"
    
    // Specialty
    case crunchyroll = "Crunchyroll"
    
    nonisolated var id: String { rawValue }
    
    /// Watch provider ID for streaming service filters (TMDB IDs for US region)
    /// Source: TMDB /watch/providers API
    nonisolated var watchProviderID: Int? {
        switch self {
        case .netflix: return 8
        case .amazonPrime: return 9 // Amazon Prime Video
        case .disneyPlus: return 337
        case .max: return 1899 // Max (formerly HBO Max) - updated ID
        case .appleTVPlus: return 350
        case .hulu: return 15
        case .paramountPlus: return 2303 // Paramount Plus Premium (531 deprecated)
        case .peacock: return 386
        case .tubi: return 73
        case .plutoTV: return 300
        case .crunchyroll: return 283
        default: return nil
        }
    }
    
    /// Whether this is a streaming service filter
    nonisolated var isStreamingService: Bool {
        watchProviderID != nil
    }
    
    /// Whether this is a free streaming service
    nonisolated var isFreeService: Bool {
        switch self {
        case .tubi, .plutoTV: return true
        default: return false
        }
    }
    
    /// SF Symbol icon name for the discovery method (never empty; use for placeholders and non-streaming methods)
    nonisolated var iconName: String {
        let name: String
        switch self {
        case .topRated: name = "star.fill"
        case .popular: name = "flame.fill"
        case .trending: name = "chart.line.uptrend.xyaxis"
        case .nowPlaying: name = "play.circle.fill"
        case .upcoming: name = "calendar"
        case .tubi, .plutoTV: name = "tv"
        case .crunchyroll: name = "sparkles"
        default: name = "tv.fill"
        }
        return name.isEmpty ? "tv.fill" : name
    }
    
    /// TMDB logo path for streaming providers (nil for non-streaming methods).
    /// Refresh from: GET https://api.themoviedb.org/3/watch/providers/movie?language=en-US&watch_region=US
    /// Provider IDs: Netflix 8, Max 1899, Paramount+ 531, Peacock 386.
    nonisolated var logoPath: String? {
        switch self {
        case .netflix: return "/wwemzKWzjKYJFfCeiB57q3r4Bcm.png"
        case .amazonPrime: return "/emthp39XA2YScoYL1p0sdbAH2WA.jpg"
        case .disneyPlus: return "/97yvRBw1GzX7fXprcF80er19ot.jpg"
        case .max: return "/fksCUZ9QDWZMUwL2LgMtLckROUN.jpg"
        case .appleTVPlus: return "/6uhKBfmtzFqOcLousHwZuzcrScK.jpg"
        case .hulu: return "/zxrVdFjIjLqkfnwyghnfywTn3Lh.jpg"
        case .paramountPlus: return "/fts6X10Jn4QT0X6ac3udKEn2tJA.jpg"
        case .peacock: return "/2aGrp1xw3qhwCYvNGAJZPdjfeeX.jpg"
        case .tubi: return "/bxDAkDCFvPcxDMz2iFTtL15PoET.jpg"
        case .plutoTV: return "/t6N57S3a3aciz2DECvo6mGz0mIJ.jpg"
        case .crunchyroll: return "/8Gt1iClBlzTeQs8WQm8UrCoIxnQ.jpg"
        default: return nil
        }
    }
    
    /// Full URL for provider logo (TMDB image base); nil for non-streaming methods
    nonisolated var logoURL: URL? {
        guard let path = logoPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w92\(path)")
    }
    
    /// Group label for organizing in UI
    nonisolated var category: Category {
        if isFreeService {
            return .free
        }
        if self == .crunchyroll {
            return .specialty
        }
        if isStreamingService {
            return .streaming
        }
        return .general
    }
    
    enum Category: String, CaseIterable, Sendable {
        case general = "Discover"
        case streaming = "Streaming Services"
        case free = "Free Streaming"
        case specialty = "Specialty"
    }
    
    /// All methods grouped by category
    nonisolated static var grouped: [(category: Category, methods: [DiscoveryMethod])] {
        Category.allCases.compactMap { category in
            let methods = allCases.filter { $0.category == category }
            return methods.isEmpty ? nil : (category, methods)
        }
    }
}

// MARK: - Content Type Filter

/// Filter for showing movies, TV shows, or both
enum ContentTypeFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case movies = "Movies"
    case tvShows = "TV Shows"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .all: return "square.stack.fill"
        case .movies: return "film.fill"
        case .tvShows: return "tv.fill"
        }
    }

    /// Short label for inline chips
    var shortLabel: String {
        switch self {
        case .all: return "All"
        case .movies: return "Movies"
        case .tvShows: return "TV"
        }
    }
}
