import Foundation
import os

/// Parses incoming Universal Link URLs and routes them to the appropriate destination.
///
/// Supported URL patterns:
/// - `https://mit112.github.io/FlickSwiper/list/{docID}` → shared list
///
/// Usage: Call `DeepLinkHandler.destination(from:)` in `.onOpenURL` or
/// `application(_:continue:restorationHandler:)`.
nonisolated enum DeepLinkHandler {
    private static let logger = Logger(subsystem: "com.flickswiper.app", category: "DeepLink")
    
    /// Possible destinations from a deep link.
    enum Destination: Equatable {
        /// A shared list that should be displayed.
        /// The associated value is the Firestore document ID.
        case sharedList(docID: String)
    }
    
    /// Parses a URL and returns the appropriate destination, or nil if unrecognized.
    static func destination(from url: URL) -> Destination? {
        logger.info("Handling deep link: \(url.absoluteString)")
        
        // Check host matches our GitHub Pages domain
        guard url.host == "mit112.github.io" else {
            logger.warning("Unrecognized host: \(url.host ?? "nil")")
            return nil
        }
        
        // Try to extract a list doc ID
        if let docID = Constants.DeepLink.listID(from: url) {
            logger.info("Parsed shared list doc ID: \(docID)")
            return .sharedList(docID: docID)
        }
        
        logger.warning("No matching route for path: \(url.path)")
        return nil
    }
}
