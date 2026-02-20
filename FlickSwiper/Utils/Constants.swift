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
        static let ratingDisplayOption = "ratingDisplayOption"
    }
    
    // MARK: - UI
    
    enum UI {
        static let cardCornerRadius: CGFloat = 20
        static let gridSpacing: CGFloat = 12
        static let prefetchThreshold: Int = 5
    }
    
    // MARK: - URLs
    
    nonisolated enum URLs {
        static let privacyPolicy = URL(string: "https://mit112.github.io/FlickSwiper/")!
        static let contactEmail = URL(string: "mailto:mitsheth82@gmail.com")!
        /// Base URL for Universal Links (shared list deep links)
        static let deepLinkBase = "https://mit112.github.io/FlickSwiper"
        /// App Store URL for fallback page redirect (update with real ID after approval)
        static let appStore = URL(string: "https://apps.apple.com/app/flickswiper/id0000000000")!
    }
    
    // MARK: - Firestore
    
    /// `nonisolated` so these can be read from any actor context.
    nonisolated enum Firestore {
        static let usersCollection = "users"
        static let publishedListsCollection = "publishedLists"
        static let followsCollection = "follows"
    }
    
    // MARK: - Deep Links
    
    nonisolated enum DeepLink {
        /// Path prefix for shared list links: /FlickSwiper/list/{docID}
        static let listPathPrefix = "/FlickSwiper/list/"
        
        /// Extract a Firestore doc ID from a Universal Link URL.
        /// Returns nil if the URL doesn't match the expected pattern.
        nonisolated static func listID(from url: URL) -> String? {
            let path = url.path
            guard path.hasPrefix(listPathPrefix) else { return nil }
            let docID = String(path.dropFirst(listPathPrefix.count))
            guard !docID.isEmpty else { return nil }
            return docID
        }
    }
}
