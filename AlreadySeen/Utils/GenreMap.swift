import Foundation

/// Static mapping of TMDB genre IDs to human-readable names and SF Symbol icons
struct GenreMap {
    
    // MARK: - Genre Name Dictionaries
    
    static let movieGenres: [Int: String] = [
        28: "Action", 12: "Adventure", 16: "Animation",
        35: "Comedy", 80: "Crime", 99: "Documentary",
        18: "Drama", 10751: "Family", 14: "Fantasy",
        36: "History", 27: "Horror", 10402: "Music",
        9648: "Mystery", 10749: "Romance", 878: "Sci-Fi",
        10770: "TV Movie", 53: "Thriller", 10752: "War",
        37: "Western"
    ]
    
    static let tvGenres: [Int: String] = [
        10759: "Action & Adventure", 16: "Animation",
        35: "Comedy", 80: "Crime", 99: "Documentary",
        18: "Drama", 10751: "Family", 10762: "Kids",
        9648: "Mystery", 10763: "News", 10764: "Reality",
        10765: "Sci-Fi & Fantasy", 10766: "Soap",
        10767: "Talk", 10768: "War & Politics", 37: "Western"
    ]
    
    /// Look up genre name by ID (checks both movie and TV dictionaries)
    static func name(for id: Int) -> String? {
        movieGenres[id] ?? tvGenres[id]
    }
    
    // MARK: - Genre Icons
    
    static let genreIcons: [Int: String] = [
        28: "flame",           // Action
        12: "map",             // Adventure
        16: "paintbrush",      // Animation
        35: "face.smiling",    // Comedy
        80: "magnifyingglass", // Crime
        99: "video",           // Documentary
        18: "theatermasks",    // Drama
        10751: "house",        // Family
        14: "sparkles",        // Fantasy
        36: "clock",           // History
        27: "eye",             // Horror
        10402: "music.note",   // Music
        9648: "questionmark.circle", // Mystery
        10749: "heart",        // Romance
        878: "atom",           // Sci-Fi
        10770: "tv",           // TV Movie
        53: "bolt",            // Thriller
        10752: "shield",       // War
        37: "sun.dust",        // Western
        10759: "flame",        // Action & Adventure (TV)
        10762: "figure.play",  // Kids (TV)
        10763: "newspaper",    // News (TV)
        10764: "person.3",     // Reality (TV)
        10765: "atom",         // Sci-Fi & Fantasy (TV)
        10766: "heart.circle", // Soap (TV)
        10767: "mic",          // Talk (TV)
        10768: "shield",       // War & Politics (TV)
    ]
    
    /// SF Symbol icon for a genre ID
    static func icon(for id: Int) -> String {
        genreIcons[id] ?? "film"
    }
}
