import SwiftUI
import SwiftData
import os

/// Search tab — debounced TMDB search with library-aware result indicators and detail views
struct SearchView: View {
    @State private var viewModel: SearchViewModel
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "SearchView")

    @Query(filter: #Predicate<SwipedItem> { $0.swipeDirection == "seen" })
    private var seenItems: [SwipedItem]
    
    @Query(filter: #Predicate<SwipedItem> { $0.swipeDirection == "watchlist" })
    private var watchlistItems: [SwipedItem]

    @Environment(\.modelContext) private var modelContext

    @State private var selectedItem: MediaItem?
    @State private var showRatingPrompt = false
    @State private var pendingSwipedItem: SwipedItem?
    @State private var pendingTitle: String?
    @State private var persistenceErrorMessage: String?

    init(mediaService: any MediaServiceProtocol = TMDBService()) {
        _viewModel = State(initialValue: SearchViewModel(mediaService: mediaService))
    }

    /// Set of unique IDs already in the user's library (composite key: "mediaType_tmdbID")
    private var seenUniqueIDs: Set<String> {
        Set(seenItems.map(\.uniqueID))
    }
    
    /// Set of unique IDs currently in the watchlist (composite key: "mediaType_tmdbID")
    private var watchlistUniqueIDs: Set<String> {
        Set(watchlistItems.map(\.uniqueID))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.searchText.isEmpty && !viewModel.hasSearched {
                    emptyPromptView
                } else if viewModel.isLoading && viewModel.results.isEmpty {
                    loadingView
                } else if viewModel.isOffline {
                    offlineView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.hasSearched && viewModel.results.isEmpty {
                    noResultsView
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Movies, TV shows..."
            )
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.search()
            }
            .sheet(item: $selectedItem) { item in
                SearchResultDetailView(
                    item: item,
                    isAlreadySeen: seenUniqueIDs.contains(item.uniqueID),
                    isInWatchlist: watchlistUniqueIDs.contains(item.uniqueID),
                    onMarkAsSeen: { markAsSeen(item) },
                    onSaveToWatchlist: { saveToWatchlist(item) }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showRatingPrompt) {
                if let title = pendingTitle {
                    ratingPromptSheet(title: title)
                }
            }
            .alert(
                "Couldn't Save Changes",
                isPresented: Binding(
                    get: { persistenceErrorMessage != nil },
                    set: { if !$0 { persistenceErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { persistenceErrorMessage = nil }
            } message: {
                Text(persistenceErrorMessage ?? "Please try again.")
            }
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.results) { item in
                    SearchResultRow(
                        item: item,
                        isAlreadySeen: seenUniqueIDs.contains(item.uniqueID),
                        isInWatchlist: watchlistUniqueIDs.contains(item.uniqueID)
                    )
                    .onTapGesture { selectedItem = item }

                    if item.id != viewModel.results.last?.id {
                        Divider()
                            .padding(.leading, 80)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Empty / Loading / Error States

    private var emptyPromptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Search for Movies & TV Shows")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Find titles to add to your library")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Searching...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Results")
                .font(.headline)

            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Offline View
    
    private var offlineView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("You're Offline")
                .font(.headline)
            
            Text("Connect to the internet to search.\nYour library is still available!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                viewModel.search()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding()
    }

    // MARK: - Mark as Seen Flow

    private func markAsSeen(_ item: MediaItem) {
        do {
            let swipedItem = try SwipedItemStore(context: modelContext).markAsSeen(from: item)
            selectedItem = nil
            pendingSwipedItem = swipedItem
            pendingTitle = item.title

            Task {
                try? await Task.sleep(for: .seconds(0.3))
                showRatingPrompt = true
            }
        } catch {
            logger.error("Failed to mark item as seen from search: \(error.localizedDescription)")
            persistenceErrorMessage = "We couldn't save this item to your library. Please try again."
        }
    }
    
    private func saveToWatchlist(_ item: MediaItem) {
        do {
            _ = try SwipedItemStore(context: modelContext).saveToWatchlist(from: item)
            selectedItem = nil
        } catch {
            logger.error("Failed to save item to watchlist from search: \(error.localizedDescription)")
            persistenceErrorMessage = "We couldn't save this item to your watchlist. Please try again."
        }
    }

    private func ratingPromptSheet(title: String) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text("How was it?")
                    .font(.title2.weight(.bold))

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            if let pendingItem = pendingSwipedItem {
                                do {
                                    try SwipedItemStore(context: modelContext).setPersonalRating(star, for: pendingItem)
                                    showRatingPrompt = false
                                    pendingSwipedItem = nil
                                    pendingTitle = nil
                                } catch {
                                    logger.error("Failed to save search rating: \(error.localizedDescription)")
                                    persistenceErrorMessage = "We couldn't save your rating. Please try again."
                                }
                            }
                        } label: {
                            Image(systemName: "star")
                                .font(.title)
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                Button("Skip") {
                    showRatingPrompt = false
                    pendingSwipedItem = nil
                    pendingTitle = nil
                }
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
        }
        .presentationDetents([.height(280)])
    }
}

// MARK: - SearchResultRow

struct SearchResultRow: View {
    let item: MediaItem
    let isAlreadySeen: Bool
    let isInWatchlist: Bool

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
            }
            .frame(width: 50, height: 75)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(item.mediaType == .movie ? "Movie" : "TV")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.gray.opacity(0.2), in: Capsule())

                    if let year = item.releaseYear {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let rating = item.ratingText {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow)
                            Text(rating)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            if isAlreadySeen {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.body)
            } else if isInWatchlist {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.blue)
                    .font(.body)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.mediaType == .movie ? "Movie" : "TV Show"), \(item.releaseYear ?? "Unknown year")\(isAlreadySeen ? ", already in library" : isInWatchlist ? ", in watchlist" : "")")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - SearchResultDetailView

struct SearchResultDetailView: View {
    let item: MediaItem
    let isAlreadySeen: Bool
    let isInWatchlist: Bool
    let onMarkAsSeen: () -> Void
    let onSaveToWatchlist: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        AsyncImage(url: item.posterURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(.gray)
                                    }
                            }
                        }
                        .frame(width: 120, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: item.mediaType == .movie ? "film" : "tv")
                                    .font(.caption2.weight(.semibold))
                                Text(item.mediaType == .movie ? "Movie" : "TV Show")
                                    .font(.caption2.weight(.semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.gray.opacity(0.15), in: Capsule())

                            Text(item.title)
                                .font(.title3.weight(.bold))

                            if let year = item.releaseYear {
                                Text(year)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let rating = item.ratingText {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                    Text(rating)
                                        .fontWeight(.semibold)
                                    Text("/ 10")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                            }

                            Spacer()
                        }
                    }
                    .padding(.horizontal)

                    if isAlreadySeen {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Already in your library")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    } else if isInWatchlist {
                        HStack {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(.blue)
                            Text("In your watchlist")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 10) {
                            Button {
                                onMarkAsSeen()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Mark as Already Seen")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.green, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                            }
                            
                            Button {
                                onSaveToWatchlist()
                            } label: {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                    Text("Save for Later")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    if !item.overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overview")
                                .font(.headline)
                            Text(item.overview)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
