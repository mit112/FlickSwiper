import Foundation

// MARK: - SeenFilter

/// Filter cases used by smart collections and the filtered grid
enum SeenFilter: Hashable {
    case favorites           // personalRating >= 4
    case movies              // mediaType == movie
    case tvShows             // mediaType == tvShow
    case genre(Int)          // specific genre ID
    case platform(String)    // specific platform name
    case recentlyAdded       // last 30 days
    case all                 // no filter
}

// MARK: - SmartCollection

/// A computed collection derived from the user's seen items.
/// Built dynamically from the user's library data — not persisted.
struct SmartCollection: Identifiable, Hashable {
    let id: String          // stable identifier
    let title: String
    let systemImage: String
    let count: Int
    let filter: SeenFilter
    let coverPosterPath: String?
}
