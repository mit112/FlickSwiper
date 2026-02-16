import SwiftUI
import SwiftData

/// Full grid view of watchlisted items with swipe-to-delete and "mark as seen" actions
struct WatchlistGridView: View {
    let items: [SwipedItem]
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var searchText = ""
    @State private var genreFilter: Int?
    @State private var typeFilter: MediaItem.MediaType?
    @State private var selectedItem: SwipedItem?
    @State private var showWatchlistRating = false
    @State private var ratingItem: SwipedItem?
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    private var displayedItems: [SwipedItem] {
        var result = items
        
        if let genre = genreFilter {
            result = result.filter { $0.genreIDs.contains(genre) }
        }
        if let type = typeFilter {
            result = result.filter { $0.mediaTypeEnum == type }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
    
    private var availableGenres: [(id: Int, name: String)] {
        var genreCounts: [Int: Int] = [:]
        for item in items {
            for genreID in item.genreIDs {
                genreCounts[genreID, default: 0] += 1
            }
        }
        return genreCounts
            .sorted { $0.value > $1.value }
            .prefix(8)
            .compactMap { id, _ in
                guard let name = GenreMap.name(for: id) else { return nil }
                return (id: id, name: name)
            }
    }
    
    private var availableTypes: [MediaItem.MediaType] {
        let types = Set(items.map(\.mediaTypeEnum))
        return types.count > 1 ? [.movie, .tvShow] : []
    }
    
    var body: some View {
        ScrollView {
            filterChips
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(displayedItems) { item in
                    SeenItemCard(item: item)
                        .overlay(alignment: .topLeading) {
                            Image(systemName: "bookmark.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(3)
                                .background(.blue, in: RoundedRectangle(cornerRadius: 3))
                                .padding(6)
                        }
                        .onTapGesture {
                            selectedItem = item
                        }
                        .contextMenu {
                            Button {
                                markAsSeen(item)
                            } label: {
                                Label("I've Watched This", systemImage: "checkmark.circle")
                            }
                            
                            Button(role: .destructive) {
                                removeFromWatchlist(item)
                            } label: {
                                Label("Remove from Watchlist", systemImage: "bookmark.slash")
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Watchlist")
        .searchable(text: $searchText, prompt: "Search watchlist...")
        .sheet(item: $selectedItem) { item in
            WatchlistItemDetailView(
                item: item,
                onMarkAsSeen: {
                    selectedItem = nil
                    markAsSeen(item)
                },
                onRemove: {
                    selectedItem = nil
                    removeFromWatchlist(item)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWatchlistRating) {
            if let item = ratingItem {
                WatchlistRatingSheet(item: item) {
                    showWatchlistRating = false
                    ratingItem = nil
                }
            }
        }
    }
    
    private func markAsSeen(_ item: SwipedItem) {
        item.swipeDirection = SwipedItem.directionSeen
        item.dateSwiped = Date()
        try? modelContext.save()
        
        ratingItem = item
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            showWatchlistRating = true
        }
    }
    
    private func removeFromWatchlist(_ item: SwipedItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
    
    private var filterChips: some View {
        Group {
            if !availableGenres.isEmpty || !availableTypes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableTypes, id: \.self) { type in
                            FilterChip(
                                label: type == .movie ? "Movies" : "TV Shows",
                                isActive: typeFilter == type,
                                action: { typeFilter = typeFilter == type ? nil : type }
                            )
                        }
                        
                        if !availableGenres.isEmpty && !availableTypes.isEmpty {
                            Divider().frame(height: 20)
                        }
                        
                        ForEach(availableGenres, id: \.id) { genre in
                            FilterChip(
                                label: genre.name,
                                isActive: genreFilter == genre.id,
                                action: { genreFilter = genreFilter == genre.id ? nil : genre.id }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

