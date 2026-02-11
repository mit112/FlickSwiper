import Foundation

/// Genre filter for movies and TV shows
/// IDs are from TMDB API
enum Genre: Int, CaseIterable, Identifiable, Codable, Sendable {
    // Common genres (work for both movies and TV)
    case action = 28
    case adventure = 12
    case animation = 16
    case comedy = 35
    case crime = 80
    case documentary = 99
    case drama = 18
    case family = 10751
    case fantasy = 14
    case history = 36
    case horror = 27
    case music = 10402
    case mystery = 9648
    case romance = 10749
    case sciFi = 878
    case thriller = 53
    case war = 10752
    case western = 37
    
    // TV-specific genres (use these IDs when filtering TV shows)
    case actionAdventureTV = 10759
    case sciFiFantasyTV = 10765
    case reality = 10764
    case kids = 10762
    
    nonisolated var id: Int { rawValue }
    
    var name: String {
        switch self {
        case .action: return "Action"
        case .adventure: return "Adventure"
        case .animation: return "Animation"
        case .comedy: return "Comedy"
        case .crime: return "Crime"
        case .documentary: return "Documentary"
        case .drama: return "Drama"
        case .family: return "Family"
        case .fantasy: return "Fantasy"
        case .history: return "History"
        case .horror: return "Horror"
        case .music: return "Music"
        case .mystery: return "Mystery"
        case .romance: return "Romance"
        case .sciFi: return "Sci-Fi"
        case .thriller: return "Thriller"
        case .war: return "War"
        case .western: return "Western"
        case .actionAdventureTV: return "Action & Adventure"
        case .sciFiFantasyTV: return "Sci-Fi & Fantasy"
        case .reality: return "Reality"
        case .kids: return "Kids"
        }
    }
    
    var iconName: String {
        switch self {
        case .action, .actionAdventureTV: return "figure.run"
        case .adventure: return "map"
        case .animation: return "paintpalette"
        case .comedy: return "face.smiling"
        case .crime: return "exclamationmark.shield"
        case .documentary: return "video"
        case .drama: return "theatermasks"
        case .family: return "figure.2.and.child.holdinghands"
        case .fantasy: return "wand.and.stars"
        case .history: return "clock.arrow.circlepath"
        case .horror: return "moon.stars"
        case .music: return "music.note"
        case .mystery: return "magnifyingglass"
        case .romance: return "heart"
        case .sciFi, .sciFiFantasyTV: return "atom"
        case .thriller: return "bolt"
        case .war: return "shield"
        case .western: return "sun.dust"
        case .reality: return "video.badge.waveform"
        case .kids: return "teddybear"
        }
    }
    
    /// Genres that make sense for movies
    static var movieGenres: [Genre] {
        [.action, .adventure, .animation, .comedy, .crime, .documentary,
         .drama, .family, .fantasy, .history, .horror, .music, .mystery,
         .romance, .sciFi, .thriller, .war, .western]
    }
    
    /// Genres that make sense for TV shows
    static var tvGenres: [Genre] {
        [.actionAdventureTV, .animation, .comedy, .crime, .documentary,
         .drama, .family, .kids, .mystery, .reality, .romance, 
         .sciFiFantasyTV, .war, .western]
    }
    
    /// Common genres that work well for both
    static var commonGenres: [Genre] {
        [.action, .animation, .comedy, .crime, .documentary, .drama,
         .family, .horror, .mystery, .romance, .sciFi, .thriller]
    }
}
