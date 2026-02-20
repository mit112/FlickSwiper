import SwiftUI
import SwiftData

/// Horizontal scroll of auto-generated smart collections.
///
/// Owns its own `@Query` for seen items instead of accepting the full array from
/// the parent. Caches the computed collections in `@State` and only rebuilds when
/// the query result changes, avoiding expensive multi-pass iteration on every
/// parent body evaluation.
struct SmartCollectionsSection: View {
    @Query(filter: #Predicate<SwipedItem> { $0.swipeDirection == "seen" },  // matches SwipedItem.directionSeen
           sort: \SwipedItem.dateSwiped, order: .reverse)
    private var seenItems: [SwipedItem]
    
    @State private var collections: [SmartCollection] = []
    
    /// Lightweight hash that changes when ratings or platforms change,
    /// triggering a rebuild of smart collections even if the count stays the same.
    private var seenItemsHash: Int {
        var hasher = Hasher()
        for item in seenItems {
            hasher.combine(item.personalRating)
            hasher.combine(item.sourcePlatform)
        }
        return hasher.finalize()
    }
    
    var body: some View {
        Group {
            if !collections.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Collections")
                        .font(.title3.weight(.bold))
                        .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(collections) { collection in
                                NavigationLink(value: collection) {
                                    SmartCollectionCard(collection: collection)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .onChange(of: seenItems.count) { _, _ in
            collections = buildCollections()
        }
        .onChange(of: seenItemsHash) { _, _ in
            collections = buildCollections()
        }
        .onAppear {
            collections = buildCollections()
        }
    }
    
    // MARK: - Build Collections
    
    private func buildCollections() -> [SmartCollection] {
        var result: [SmartCollection] = []
        
        // My Favorites (rating >= 4)
        let favorites = seenItems.filter { ($0.personalRating ?? 0) >= 4 }
        if !favorites.isEmpty {
            result.append(SmartCollection(
                id: "favorites",
                title: "My Favorites",
                systemImage: "heart.fill",
                count: favorites.count,
                filter: .favorites,
                coverPosterPath: favorites.first?.posterPath
            ))
        }
        
        // Movies vs TV — only show if user has both types
        let movies = seenItems.filter { $0.mediaTypeEnum == .movie }
        let tvShows = seenItems.filter { $0.mediaTypeEnum == .tvShow }
        
        if !movies.isEmpty && !tvShows.isEmpty {
            result.append(SmartCollection(
                id: "movies",
                title: "Movies",
                systemImage: "film",
                count: movies.count,
                filter: .movies,
                coverPosterPath: movies.first?.posterPath
            ))
            result.append(SmartCollection(
                id: "tvshows",
                title: "TV Shows",
                systemImage: "tv",
                count: tvShows.count,
                filter: .tvShows,
                coverPosterPath: tvShows.first?.posterPath
            ))
        }
        
        // Per genre
        result.append(contentsOf: genreCollections(from: seenItems))
        
        // Per platform
        result.append(contentsOf: platformCollections(from: seenItems))
        
        // Recently Added (last 30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = seenItems.filter { $0.dateSwiped >= thirtyDaysAgo }
        if !recent.isEmpty {
            result.append(SmartCollection(
                id: "recent",
                title: "Recently Added",
                systemImage: "clock",
                count: recent.count,
                filter: .recentlyAdded,
                coverPosterPath: recent.first?.posterPath
            ))
        }
        
        return result
    }
    
    // MARK: - Genre Collections
    
    private func genreCollections(from items: [SwipedItem]) -> [SmartCollection] {
        var genreCounts: [Int: (count: Int, coverPoster: String?)] = [:]
        
        for item in items {
            for genreID in item.genreIDs {
                if genreCounts[genreID] == nil {
                    genreCounts[genreID] = (1, item.posterPath)
                } else {
                    genreCounts[genreID]!.count += 1
                }
            }
        }
        
        return genreCounts
            .filter { $0.value.count >= 2 }
            .sorted { $0.value.count > $1.value.count }
            .prefix(10)
            .compactMap { id, data in
                guard let name = GenreMap.name(for: id) else { return nil }
                return SmartCollection(
                    id: "genre_\(id)",
                    title: name,
                    systemImage: GenreMap.icon(for: id),
                    count: data.count,
                    filter: .genre(id),
                    coverPosterPath: data.coverPoster
                )
            }
    }
    
    // MARK: - Platform Collections
    
    private func platformCollections(from items: [SwipedItem]) -> [SmartCollection] {
        var platformCounts: [String: (count: Int, coverPoster: String?)] = [:]
        
        for item in items {
            guard let platform = item.sourcePlatform else { continue }
            if platformCounts[platform] == nil {
                platformCounts[platform] = (1, item.posterPath)
            } else {
                platformCounts[platform]!.count += 1
            }
        }
        
        return platformCounts
            .sorted { $0.value.count > $1.value.count }
            .map { platform, data in
                SmartCollection(
                    id: "platform_\(platform)",
                    title: platform,
                    systemImage: "tv.fill",
                    count: data.count,
                    filter: .platform(platform),
                    coverPosterPath: data.coverPoster
                )
            }
    }
}
