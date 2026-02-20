import SwiftUI

/// UIActivityViewController wrapper for presenting a share sheet with a URL.
///
/// Used when we need to share programmatically (e.g. after publishing a list)
/// rather than declaratively via `ShareLink`.
struct ShareLinkSheet: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}
