import Foundation

/// App-wide constants
enum Constants {
    
    // MARK: - API
    
    enum API {
        static let tmdbBaseURL = "https://api.themoviedb.org/3"
        static let tmdbImageBaseURL = "https://image.tmdb.org/t/p"
        static let defaultWatchRegion = "US"
    }
    
    // MARK: - Animation
    
    enum Animation {
        static let swipeThreshold: CGFloat = 100
        static let maxRotation: Double = 12
        static let cardStackCount: Int = 3
    }
    
    // MARK: - Storage Keys
    
    enum StorageKeys {
        static let selectedDiscoveryMethod = "selectedDiscoveryMethod"
        static let contentTypeFilter = "contentTypeFilter"
    }
    
    // MARK: - UI
    
    enum UI {
        static let cardCornerRadius: CGFloat = 20
        static let gridSpacing: CGFloat = 12
        static let prefetchThreshold: Int = 5
    }
}
