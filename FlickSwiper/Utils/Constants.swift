import Foundation

/// App-wide constants
enum Constants {
    
    // MARK: - Animation

    enum Animation {
        static let swipeThreshold: CGFloat = 100
        static let maxRotation: Double = 12
    }
    
    // MARK: - Storage Keys
    
    enum StorageKeys {
        static let selectedDiscoveryMethod = "selectedDiscoveryMethod"
        static let contentTypeFilter = "contentTypeFilter"
        static let hasSeenSwipeTutorial = "hasSeenSwipeTutorial"
        static let includeSwipedItems = "includeSwipedItems"
        static let ratingDisplayOption = "ratingDisplayOption"
    }
    
    // MARK: - URLs
    
    nonisolated enum URLs {
        static let privacyPolicy = URL(string: "https://mit112.github.io/FlickSwiper/")!
        static let contactEmail = URL(string: "mailto:mitsheth82@gmail.com")!
        /// Base URL for Universal Links (shared list deep links)
        static let deepLinkBase = "https://mit112.github.io/FlickSwiper"
        /// App Store URL for fallback page redirect (update with real ID after approval)
        static let appStore = URL(string: "https://apps.apple.com/us/app/flickswiper/id6758966666")!
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
            // Strip trailing slashes, backslashes, and whitespace that can appear
            // from URL copy-paste or encoding artifacts
            let raw = String(path.dropFirst(listPathPrefix.count))
            let docID = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/\\ \t\n"))
            guard !docID.isEmpty else { return nil }
            // Validate doc ID: only allow alphanumeric, hyphens, and underscores.
            // Rejects path traversal (../), slashes, and other unexpected characters.
            // Firestore auto-IDs use this charset; anything else is suspicious.
            guard docID.count <= 128,
                  docID.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
                return nil
            }
            return docID
        }
    }
}
