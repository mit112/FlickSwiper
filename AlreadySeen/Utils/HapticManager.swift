import UIKit

/// Centralized haptic feedback manager
/// Consolidates haptic feedback logic to avoid code duplication
enum HapticManager {
    
    /// Trigger impact haptic feedback
    /// - Parameter style: The intensity of the impact feedback
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    /// Trigger notification haptic feedback
    /// - Parameter type: The type of notification feedback
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    /// Trigger selection changed haptic feedback
    static func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    // MARK: - Convenience Methods
    
    /// Light impact for skip actions
    static func skip() {
        impact(.light)
    }
    
    /// Medium impact for seen/confirm actions
    static func seen() {
        impact(.medium)
    }
    
    /// Rigid impact for undo actions
    static func undo() {
        impact(.rigid)
    }
}
