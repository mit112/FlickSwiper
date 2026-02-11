import SwiftUI
import SwiftData

/// ViewModel for the Search tab — manages debounced TMDB search with 400ms delay via Task cancellation
@Observable
final class SearchViewModel {
    var searchText = ""
    var results: [MediaItem] = []
    var isLoading = false
    var hasSearched = false
    var errorMessage: String?

    private let service = TMDBService()
    private var searchTask: Task<Void, Never>?

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

            await MainActor.run { isLoading = true; errorMessage = nil }

            do {
                let items = try await service.searchMulti(query: query)

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.results = items
                    self.isLoading = false
                    self.hasSearched = true
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.hasSearched = true
                }
            }
        }
    }
}
