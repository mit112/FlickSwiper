import SwiftUI

// MARK: - View Extensions

extension View {
    /// Apply a shadow effect for cards
    func cardShadow() -> some View {
        self.shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    /// Hide the view conditionally
    @ViewBuilder
    func hidden(_ isHidden: Bool) -> some View {
        if isHidden {
            self.hidden()
        } else {
            self
        }
    }
    
    /// Apply spring animation
    func springAnimation() -> some View {
        self.animation(.spring(response: 0.4, dampingFraction: 0.7), value: UUID())
    }
}

// MARK: - Color Extensions

extension Color {
    /// App accent color
    static let appAccent = Color.accentColor
    
    /// Success color (green)
    static let success = Color.green
    
    /// Skip color (gray)
    static let skip = Color.gray
}

// MARK: - String Extensions

extension String {
    /// Returns the year portion of a date string (YYYY-MM-DD format)
    var yearFromDate: String? {
        guard self.count >= 4 else { return nil }
        return String(self.prefix(4))
    }
}

// MARK: - Optional Extensions

extension Optional where Wrapped == String {
    /// Returns true if the string is nil or empty
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}

// MARK: - Array Extensions

extension Array {
    /// Safely access array element at index
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Date Extensions

extension Date {
    /// Format date as relative string
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Format date as medium style
    var mediumFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}
