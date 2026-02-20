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
}

// MARK: - Button Styles

/// Scale-down press effect for cards and tappable containers
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
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
    /// Shared formatters — `DateFormatter` is expensive to create, so these are reused.
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
    
    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Format date as relative string (e.g. "2 days ago")
    var relativeFormatted: String {
        Self.relativeDateFormatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Format date as medium style (e.g. "Feb 15, 2026")
    var mediumFormatted: String {
        Self.mediumDateFormatter.string(from: self)
    }
}
