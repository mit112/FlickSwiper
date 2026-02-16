import Foundation

/// Utility for identifying network connectivity errors.
///
/// Used by ViewModels to distinguish "you're offline" from other API failures,
/// so the UI can show a dedicated offline state instead of a generic error.
enum NetworkError {
    
    /// URLError codes that indicate the device has no network connectivity.
    /// These are distinct from server errors, timeouts, or other transient failures.
    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet,    // No network interface available
        .networkConnectionLost,      // Connection dropped mid-request
        .dataNotAllowed,            // Cellular data disabled for this app
    ]
    
    /// Returns true if the error is a connectivity issue (device is offline).
    static func isOffline(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        return offlineCodes.contains(urlError.code)
    }
}
