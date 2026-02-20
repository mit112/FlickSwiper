import Foundation
import os

/// Validates display names against format rules and an offensive-term blocklist.
///
/// Rules:
/// - 2–30 characters after trimming whitespace
/// - No newlines or control characters
/// - Must not contain terms from the bundled offensive_terms.json blocklist
/// - Uniqueness is NOT enforced (UIDs are the real identity)
nonisolated struct DisplayNameValidator {
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "DisplayNameValidator")
    
    /// Minimum allowed character count after trimming
    static let minLength = 2
    /// Maximum allowed character count after trimming
    static let maxLength = 30
    
    /// Default name when Apple doesn't provide one
    static let defaultName = "FlickSwiper User"
    
    /// Cached set of blocked terms (lowercase) loaded from the bundle
    private let blockedTerms: Set<String>
    
    init() {
        self.blockedTerms = Self.loadBlockedTerms()
    }
    
    // MARK: - Validation
    
    enum ValidationError: LocalizedError {
        case tooShort
        case tooLong
        case containsNewlines
        case containsOffensiveTerm
        case emptyAfterTrimming
        
        var errorDescription: String? {
            switch self {
            case .tooShort:
                return "Name must be at least 2 characters."
            case .tooLong:
                return "Name must be 30 characters or fewer."
            case .containsNewlines:
                return "Name cannot contain line breaks."
            case .containsOffensiveTerm:
                return "This name contains language that isn't allowed."
            case .emptyAfterTrimming:
                return "Name cannot be blank."
            }
        }
    }
    
    /// Validates and sanitizes a display name.
    /// Returns the trimmed name on success, or throws a `ValidationError`.
    func validate(_ rawName: String) throws -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespaces)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyAfterTrimming
        }
        
        guard !trimmed.contains(where: \.isNewline) else {
            throw ValidationError.containsNewlines
        }
        
        guard trimmed.count >= Self.minLength else {
            throw ValidationError.tooShort
        }
        
        guard trimmed.count <= Self.maxLength else {
            throw ValidationError.tooLong
        }
        
        // Check against blocklist — lowercase comparison, check substrings
        let lowercased = trimmed.lowercased()
        for term in blockedTerms {
            if lowercased.contains(term) {
                throw ValidationError.containsOffensiveTerm
            }
        }
        
        return trimmed
    }
    
    /// Builds a display name from Apple's PersonNameComponents.
    /// Falls back to `defaultName` if Apple didn't provide a name.
    func displayName(from nameComponents: PersonNameComponents?) -> String {
        guard let components = nameComponents else {
            return Self.defaultName
        }
        
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let formatted = formatter.string(from: components).trimmingCharacters(in: .whitespaces)
        
        guard !formatted.isEmpty else {
            return Self.defaultName
        }
        
        // Truncate if Apple somehow gives us a very long name
        if formatted.count > Self.maxLength {
            return String(formatted.prefix(Self.maxLength))
        }
        
        return formatted
    }
    
    // MARK: - Blocklist Loading
    
    private static func loadBlockedTerms() -> Set<String> {
        guard let url = Bundle.main.url(forResource: "offensive_terms", withExtension: "json") else {
            Logger(subsystem: "com.flickswiper.app", category: "DisplayNameValidator")
                .warning("offensive_terms.json not found in bundle — name filtering disabled")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let terms = try JSONDecoder().decode([String].self, from: data)
            return Set(terms.map { $0.lowercased() })
        } catch {
            Logger(subsystem: "com.flickswiper.app", category: "DisplayNameValidator")
                .error("Failed to load offensive terms: \(error.localizedDescription)")
            return []
        }
    }
}
