@preconcurrency import Foundation

/// Service for interacting with The Movie Database (TMDB) API
actor TMDBService: MediaServiceProtocol {
    
    // MARK: - Configuration
    
    /// Resolve the TMDB API Read Access Token (v4 auth) from Info.plist.
    /// Throws `TMDBError.noAPIKey` instead of crashing if the token is missing or
    /// still set to the placeholder value from the xcconfig template.
    ///
    /// Get your token at: https://www.themoviedb.org/settings/api
    private func resolveAPIToken() throws -> String {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "TMDB_API_TOKEN") as? String,
              !token.isEmpty,
              token != "YOUR_TOKEN_HERE",
              !token.hasPrefix("$(") else {
            throw TMDBError.noAPIKey
        }
        return token
    }
    
    private let baseURL = "https://api.themoviedb.org/3"
    
    /// Default region for watch provider filtering (US)
    private let watchRegion = "US"

    /// Builds a stable YYYY-MM-DD date string for TMDB query params.
    /// Uses a fresh formatter to avoid shared mutable formatter state across concurrency contexts.
    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public API Methods
    
    /// Fetch content based on the selected discovery method
    func fetchContent(
        for method: DiscoveryMethod,
        contentType: ContentTypeFilter = .all,
        genre: Genre? = nil,
        page: Int = 1,
        sort: StreamingSortOption = .popular,
        yearMin: Int? = nil,
        yearMax: Int? = nil
    ) async throws -> [MediaItem] {

        // If genre is specified, use discover endpoint for better filtering
        if let genre = genre {
            return try await fetchByGenre(
                genre: genre,
                method: method,
                contentType: contentType,
                page: page,
                yearMin: yearMin,
                yearMax: yearMax
            )
        }

        // Handle streaming service filters
        if let providerID = method.watchProviderID {
            return try await fetchByWatchProvider(
                providerID: providerID,
                contentType: contentType,
                page: page,
                sort: sort,
                yearMin: yearMin,
                yearMax: yearMax
            )
        }
        
        // For general discovery methods, use /discover/ when year filters are active
        // so the API can handle filtering server-side
        if yearMin != nil || yearMax != nil {
            return try await fetchWithDiscoverEndpoint(
                method: method,
                contentType: contentType,
                page: page,
                yearMin: yearMin,
                yearMax: yearMax
            )
        }
        
        // Handle general discovery methods (no year filter)
        switch method {
        case .topRated:
            return try await fetchTopRated(contentType: contentType, page: page)
        case .popular:
            return try await fetchPopular(contentType: contentType, page: page)
        case .trending:
            return try await fetchTrending(contentType: contentType, page: page)
        case .nowPlaying:
            return try await fetchNowPlaying(contentType: contentType, page: page)
        case .upcoming:
            return try await fetchUpcoming(contentType: contentType, page: page)
        default:
            return []
        }
    }
    
    /// Fetch content filtered by genre
    func fetchByGenre(
        genre: Genre,
        method: DiscoveryMethod,
        contentType: ContentTypeFilter,
        page: Int,
        yearMin: Int? = nil,
        yearMax: Int? = nil
    ) async throws -> [MediaItem] {
        var items: [MediaItem] = []
        
        // Build sort parameter based on method
        let sortBy: String
        switch method {
        case .topRated:
            sortBy = "vote_average.desc"
        case .trending, .popular:
            sortBy = "popularity.desc"
        case .nowPlaying:
            sortBy = "primary_release_date.desc"
        case .upcoming:
            sortBy = "primary_release_date.asc"
        default:
            sortBy = "popularity.desc"
        }
        
        // Build base params
        var movieParams: [String: String] = [
            "with_genres": "\(genre.id)",
            "sort_by": sortBy,
            "vote_count.gte": "50" // Ensure quality results
        ]
        movieYearParams(yearMin: yearMin, yearMax: yearMax).forEach { movieParams[$0.key] = $0.value }
        
        var tvParams: [String: String] = [
            "with_genres": "\(genre.id)",
            "sort_by": sortBy,
            "vote_count.gte": "50"
        ]
        tvYearParams(yearMin: yearMin, yearMax: yearMax).forEach { tvParams[$0.key] = $0.value }
        
        // Add streaming provider if applicable
        if let providerID = method.watchProviderID {
            movieParams["with_watch_providers"] = "\(providerID)"
            movieParams["watch_region"] = watchRegion
            tvParams["with_watch_providers"] = "\(providerID)"
            tvParams["watch_region"] = watchRegion
        }
        
        if method == .upcoming {
            let today = todayString()
            movieParams["primary_release_date.gte"] = today
            tvParams["first_air_date.gte"] = today
        }
        
        // Fetch movies
        if contentType == .all || contentType == .movies {
            let movies = try await fetchMovies(
                endpoint: "/discover/movie",
                page: page,
                additionalParams: movieParams
            )
            items.append(contentsOf: movies)
        }
        
        // Fetch TV shows (use TV-appropriate genre if available)
        if contentType == .all || contentType == .tvShows {
            // Map movie genre ID to TV genre ID if needed
            let tvGenreID = mapGenreForTV(genre)
            tvParams["with_genres"] = "\(tvGenreID)"
            
            let tvShows = try await fetchTVShows(
                endpoint: "/discover/tv",
                page: page,
                additionalParams: tvParams
            )
            items.append(contentsOf: tvShows)
        }
        
        return items.shuffled()
    }
    
    /// Map movie genre IDs to TV-appropriate genre IDs
    private func mapGenreForTV(_ genre: Genre) -> Int {
        switch genre {
        case .action, .adventure:
            return Genre.actionAdventureTV.id
        case .sciFi, .fantasy:
            return Genre.sciFiFantasyTV.id
        default:
            return genre.id
        }
    }
    
    // MARK: - Year Filter Helpers
    
    /// Build date range params for movie discover endpoint
    private func movieYearParams(yearMin: Int?, yearMax: Int?) -> [String: String] {
        var params: [String: String] = [:]
        if let min = yearMin {
            params["primary_release_date.gte"] = "\(min)-01-01"
        }
        if let max = yearMax {
            params["primary_release_date.lte"] = "\(max)-12-31"
        }
        return params
    }
    
    /// Build date range params for TV discover endpoint
    private func tvYearParams(yearMin: Int?, yearMax: Int?) -> [String: String] {
        var params: [String: String] = [:]
        if let min = yearMin {
            params["first_air_date.gte"] = "\(min)-01-01"
        }
        if let max = yearMax {
            params["first_air_date.lte"] = "\(max)-12-31"
        }
        return params
    }
    
    /// Fetch using /discover/ endpoints when year filters require server-side filtering.
    /// This replaces the standard list endpoints (e.g. /movie/popular) which don't
    /// support date range parameters.
    private func fetchWithDiscoverEndpoint(
        method: DiscoveryMethod,
        contentType: ContentTypeFilter,
        page: Int,
        yearMin: Int?,
        yearMax: Int?
    ) async throws -> [MediaItem] {
        var items: [MediaItem] = []
        
        let sortBy: String
        switch method {
        case .topRated:
            sortBy = "vote_average.desc"
        case .popular, .trending:
            sortBy = "popularity.desc"
        case .nowPlaying:
            sortBy = "primary_release_date.desc"
        case .upcoming:
            sortBy = "primary_release_date.asc"
        default:
            sortBy = "popularity.desc"
        }
        
        if contentType == .all || contentType == .movies {
            var movieParams = movieYearParams(yearMin: yearMin, yearMax: yearMax)
            movieParams["sort_by"] = sortBy
            if method == .topRated {
                movieParams["vote_count.gte"] = "50"
            }
            if method == .upcoming {
                let today = todayString()
                // Only override gte if yearMin isn't already later than today
                if movieParams["primary_release_date.gte"] == nil || movieParams["primary_release_date.gte"]! < today {
                    movieParams["primary_release_date.gte"] = today
                }
            }
            let movies = try await fetchMovies(
                endpoint: "/discover/movie",
                page: page,
                additionalParams: movieParams
            )
            items.append(contentsOf: movies)
        }
        
        if contentType == .all || contentType == .tvShows {
            var tvParams = tvYearParams(yearMin: yearMin, yearMax: yearMax)
            tvParams["sort_by"] = sortBy
            if method == .topRated {
                tvParams["vote_count.gte"] = "50"
            }
            if method == .upcoming {
                let today = todayString()
                if tvParams["first_air_date.gte"] == nil || tvParams["first_air_date.gte"]! < today {
                    tvParams["first_air_date.gte"] = today
                }
            }
            let tvShows = try await fetchTVShows(
                endpoint: "/discover/tv",
                page: page,
                additionalParams: tvParams
            )
            items.append(contentsOf: tvShows)
        }
        
        return items.shuffled()
    }
    
    // MARK: - Discovery Methods
    
    /// Fetch top rated movies and/or TV shows
    func fetchTopRated(contentType: ContentTypeFilter, page: Int) async throws -> [MediaItem] {
        var items: [MediaItem] = []
        
        if contentType == .all || contentType == .movies {
            let movies = try await fetchMovies(endpoint: "/movie/top_rated", page: page)
            items.append(contentsOf: movies)
        }
        
        if contentType == .all || contentType == .tvShows {
            let tvShows = try await fetchTVShows(endpoint: "/tv/top_rated", page: page)
            items.append(contentsOf: tvShows)
        }
        
        return items.shuffled()
    }
    
    /// Fetch popular movies and/or TV shows
    func fetchPopular(contentType: ContentTypeFilter, page: Int) async throws -> [MediaItem] {
        var items: [MediaItem] = []
        
        if contentType == .all || contentType == .movies {
            let movies = try await fetchMovies(endpoint: "/movie/popular", page: page)
            items.append(contentsOf: movies)
        }
        
        if contentType == .all || contentType == .tvShows {
            let tvShows = try await fetchTVShows(endpoint: "/tv/popular", page: page)
            items.append(contentsOf: tvShows)
        }
        
        return items.shuffled()
    }
    
    /// Fetch trending movies and/or TV shows
    func fetchTrending(contentType: ContentTypeFilter, page: Int) async throws -> [MediaItem] {
        // Trending endpoint returns mixed results with media_type field
        if contentType == .all {
            return try await fetchTrendingAll(page: page)
        }
        
        var items: [MediaItem] = []
        
        if contentType == .movies {
            let movies = try await fetchMovies(endpoint: "/trending/movie/day", page: page)
            items.append(contentsOf: movies)
        }
        
        if contentType == .tvShows {
            let tvShows = try await fetchTVShows(endpoint: "/trending/tv/day", page: page)
            items.append(contentsOf: tvShows)
        }
        
        return items
    }
    
    /// Fetch now playing movies and on-air TV shows
    func fetchNowPlaying(contentType: ContentTypeFilter, page: Int) async throws -> [MediaItem] {
        var items: [MediaItem] = []
        
        if contentType == .all || contentType == .movies {
            let movies = try await fetchMovies(endpoint: "/movie/now_playing", page: page)
            items.append(contentsOf: movies)
        }
        
        if contentType == .all || contentType == .tvShows {
            let tvShows = try await fetchTVShows(endpoint: "/tv/on_the_air", page: page)
            items.append(contentsOf: tvShows)
        }
        
        return items.shuffled()
    }
    
    /// Fetch upcoming movies and upcoming TV shows (release date from today forward only)
    func fetchUpcoming(contentType: ContentTypeFilter, page: Int) async throws -> [MediaItem] {
        var items: [MediaItem] = []
        let today = todayString()
        
        if contentType == .all || contentType == .movies {
            let params: [String: String] = [
                "primary_release_date.gte": today,
                "sort_by": "primary_release_date.asc",
                "with_release_type": "2|3",
                "vote_count.gte": "0"
            ]
            let movies = try await fetchMovies(
                endpoint: "/discover/movie",
                page: page,
                additionalParams: params
            )
            items.append(contentsOf: movies)
        }
        
        if contentType == .all || contentType == .tvShows {
            let params: [String: String] = [
                "first_air_date.gte": today,
                "sort_by": "first_air_date.asc"
            ]
            let tvShows = try await fetchTVShows(
                endpoint: "/discover/tv",
                page: page,
                additionalParams: params
            )
            items.append(contentsOf: tvShows)
        }
        
        return items.shuffled()
    }
    
    /// Fetch content by watch provider (streaming service)
    func fetchByWatchProvider(
        providerID: Int,
        contentType: ContentTypeFilter,
        page: Int,
        sort: StreamingSortOption = .popular,
        yearMin: Int? = nil,
        yearMax: Int? = nil
    ) async throws -> [MediaItem] {
        var items: [MediaItem] = []

        if contentType == .all || contentType == .movies {
            var movieParams: [String: String] = [
                "with_watch_providers": "\(providerID)",
                "watch_region": watchRegion,
                "sort_by": sort.movieSortParam
            ]
            if sort == .topRated {
                movieParams["vote_count.gte"] = "50"
            }
            movieYearParams(yearMin: yearMin, yearMax: yearMax).forEach { movieParams[$0.key] = $0.value }
            let movies = try await fetchMovies(
                endpoint: "/discover/movie",
                page: page,
                additionalParams: movieParams
            )
            items.append(contentsOf: movies)
        }

        if contentType == .all || contentType == .tvShows {
            var tvParams: [String: String] = [
                "with_watch_providers": "\(providerID)",
                "watch_region": watchRegion,
                "sort_by": sort.tvSortParam
            ]
            if sort == .topRated {
                tvParams["vote_count.gte"] = "50"
            }
            tvYearParams(yearMin: yearMin, yearMax: yearMax).forEach { tvParams[$0.key] = $0.value }
            let tvShows = try await fetchTVShows(
                endpoint: "/discover/tv",
                page: page,
                additionalParams: tvParams
            )
            items.append(contentsOf: tvShows)
        }

        if sort == .popular {
            return items.shuffled()
        }
        return items
    }

    /// Search for movies and TV shows
    func searchMulti(query: String, page: Int = 1) async throws -> [MediaItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }

        let params: [String: String] = [
            "query": query,
            "page": "\(page)",
            "include_adult": "false",
            "language": "en-US"
        ]

        let response: TMDBResponse<TMDBTrendingItem> = try await request(
            endpoint: "/search/multi",
            params: params
        )

        return response.results
            .filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
            .map { MediaItem(from: $0) }
    }
    
    // MARK: - Private Fetch Methods
    
    /// Fetch movies from a specific endpoint
    private func fetchMovies(
        endpoint: String,
        page: Int,
        additionalParams: [String: String] = [:]
    ) async throws -> [MediaItem] {
        var params = additionalParams
        params["page"] = "\(page)"
        
        let response: TMDBResponse<TMDBMovie> = try await request(endpoint: endpoint, params: params)
        return response.results.map { MediaItem(from: $0) }
    }
    
    /// Fetch TV shows from a specific endpoint
    private func fetchTVShows(
        endpoint: String,
        page: Int,
        additionalParams: [String: String] = [:]
    ) async throws -> [MediaItem] {
        var params = additionalParams
        params["page"] = "\(page)"
        
        let response: TMDBResponse<TMDBTVShow> = try await request(endpoint: endpoint, params: params)
        return response.results.map { MediaItem(from: $0) }
    }
    
    /// Fetch trending all (mixed movies and TV shows)
    private func fetchTrendingAll(page: Int) async throws -> [MediaItem] {
        let endpoint = "/trending/all/day"
        let params = ["page": "\(page)"]
        
        let response: TMDBResponse<TMDBTrendingItem> = try await request(endpoint: endpoint, params: params)
        return response.results
            .filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
            .map { MediaItem(from: $0) }
    }
    
    // MARK: - Network Request
    
    /// Generic request method for TMDB API
    private func request<T: Decodable>(
        endpoint: String,
        params: [String: String] = [:]
    ) async throws -> T {
        // Resolve API token (throws .noAPIKey if missing or placeholder)
        let token = try resolveAPIToken()
        
        // Build URL with query parameters
        guard var components = URLComponents(string: baseURL + endpoint) else {
            throw TMDBError.invalidURL
        }
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components.url else {
            throw TMDBError.invalidURL
        }
        
        // Create request with Bearer token authorization
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        // Check response status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        
        switch httpResponse.statusCode {
        case 200...299:
            break // success, continue to decode below
        case 429:
            // Rate limited — wait and retry once
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap(Double.init) ?? 2.0
            try await Task.sleep(for: .seconds(min(retryAfter, 10)))
            let (retryData, retryResponse) = try await URLSession.shared.data(for: urlRequest)
            guard let retryHttp = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHttp.statusCode) else {
                throw TMDBError.rateLimited
            }
            do {
                return try decoder.decode(T.self, from: retryData)
            } catch {
                throw TMDBError.decodingError(error)
            }
        default:
            throw TMDBError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Decode response
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw TMDBError.decodingError(error)
        }
    }
    
    // MARK: - Image URLs
    
    /// Get full URL for poster image
    static func posterURL(path: String?, size: PosterSize = .w500) -> URL? {
        guard let path = path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size.rawValue)\(path)")
    }
    
    enum PosterSize: String {
        case w92, w154, w185, w342, w500, w780, original
    }
}

// MARK: - Errors

enum TMDBError: LocalizedError {
    case invalidURL
    case invalidResponse
    case rateLimited
    case httpError(statusCode: Int)
    case decodingError(Error)
    case noAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not connect to the movie database."
        case .invalidResponse:
            return "Received an unexpected response. Please try again."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .httpError(let statusCode):
            return "Something went wrong (error \(statusCode)). Please try again."
        case .decodingError:
            return "Couldn't read the movie data. Please try again."
        case .noAPIKey:
            return "The app isn't configured correctly. Please reinstall or contact support."
        }
    }
}
