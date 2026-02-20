import Foundation

/// Controls which rating appears under posters in library grid views.
///
/// Stored in UserDefaults via `@AppStorage`. The raw string value is persisted,
/// so renaming a case would break existing users — add new cases, don't rename.
enum RatingDisplayOption: String, CaseIterable, Identifiable, Sendable {
    /// TMDB community rating (e.g. "7.6") — default, matches pre-feature behavior
    case tmdb = "TMDB Rating"
    /// User's personal 1–5 star rating (e.g. "4★")
    case personal = "My Rating"
    /// No rating shown — more visual space for poster art
    case none = "None"
    
    var id: String { rawValue }
}
