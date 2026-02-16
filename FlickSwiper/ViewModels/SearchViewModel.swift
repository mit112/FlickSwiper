import SwiftUI
import SwiftData

/// ViewModel for the Search tab — manages debounced TMDB search with 400ms delay via Task cancellation.
///
/// Explicitly `@MainActor` because all properties drive UI bindings via `@Observable`.
/// Matches the isolation pattern used by `SwipeViewModel`.
@MainActor
@Observable
final class SearchViewModel {
    var searchText = ""
    private(set) var results: [MediaItem] = []
    private(set) var isLoading = false
    private(set) var hasSearched = false
    private(set) var errorMessage: String?
    
    /// Whether the last failure was due to no network connectivity.
    /// Drives a dedicated offline state in SearchView.
    private(set) var isOffline = false

    /// Media service instance (injectable for testing)
    private let service: any MediaServiceProtocol
    private var searchTask: Task<Void, Never>?

    /// Initialize with optional media service for dependency injection
    /// - Parameter mediaService: Service to use for search. Defaults to TMDBService.
    init(mediaService: any MediaServiceProtocol = TMDBService()) {
        self.service = mediaService
    }

    /// Debounced search — call this from .onChange of searchText
    func search() {
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespaces)

        guard !query.isEmpty else {
            results = []
            hasSearched = false
            errorMessage = nil
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .seconds(0.4))

            guard !Task.isCancelled else { return }

            isLoading = true
            errorMessage = nil
            isOffline = false

            do {
                let items = try await service.searchMulti(query: query, page: 1)

                guard !Task.isCancelled else { return }

                results = items
                isLoading = false
                hasSearched = true
            } catch {
                guard !Task.isCancelled else { return }

                isOffline = NetworkError.isOffline(error)
                errorMessage = error.localizedDescription
                isLoading = false
                hasSearched = true
            }
        }
    }
}
