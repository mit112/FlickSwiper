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
        static let hasSeenSwipeTutorial = "hasSeenSwipeTutorial"
        static let includeSwipedItems = "includeSwipedItems"
    }
    
    // MARK: - UI
    
    enum UI {
        static let cardCornerRadius: CGFloat = 20
        static let gridSpacing: CGFloat = 12
        static let prefetchThreshold: Int = 5
    }
    
    // MARK: - URLs
    
    enum URLs {
        static let privacyPolicy = URL(string: "https://mit112.github.io/FlickSwiper/")!
        static let contactEmail = URL(string: "mailto:mitsheth82@gmail.com")!
    }
}
