import SwiftUI
import SwiftData

/// New landing page for the "Already Seen" tab
/// Shows smart collections, user lists, recently added, and a "View All" link
struct AlreadySeenHomeView: View {
    @Query(filter: #Predicate<SwipedItem> { $0.swipeDirection == "seen" },
           sort: \SwipedItem.dateSwiped, order: .reverse)
    private var seenItems: [SwipedItem]
    
    @Query(filter: #Predicate<SwipedItem> { $0.swipeDirection == "watchlist" },
           sort: \SwipedItem.dateSwiped, order: .reverse)
    private var watchlistItems: [SwipedItem]
    
    @Query(sort: \UserList.sortOrder) private var userLists: [UserList]
    @Query private var allEntries: [ListEntry]
    @Environment(\.modelContext) private var modelContext
    
    @State private var searchText = ""
    @State private var selectedItem: SwipedItem?
    @State private var selectedWatchlistItem: SwipedItem?
    @State private var showWatchlistRating = false
    @State private var ratingItem: SwipedItem?
    
    var body: some View {
        NavigationStack {
            Group {
                if seenItems.isEmpty && watchlistItems.isEmpty {
                    emptyStateView
                } else if !searchText.isEmpty {
                    // When searching, show filtered grid directly
                    searchResultsView
                } else {
                    homeScrollView
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search titles...")
            .navigationDestination(for: SmartCollection.self) { collection in
                FilteredGridView(
                    title: collection.title,
                    items: seenItems,
                    initialFilter: collection.filter
                )
            }
            .navigationDestination(for: UserList.self) { list in
                listDetailView(for: list)
            }
            .sheet(item: $selectedItem) { item in
                SeenItemDetailView(item: item)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedWatchlistItem) { item in
                WatchlistItemDetailView(
                    item: item,
                    onMarkAsSeen: {
                        // Convert to seen and update date so it appears in Recently Added
                        item.swipeDirection = SwipedItem.SwipeDirection.seen.rawValue
                        item.dateSwiped = Date()
                        try? modelContext.save()
                        
                        selectedWatchlistItem = nil
                        
                        ratingItem = item
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showWatchlistRating = true
                        }
                    },
                    onRemove: {
                        modelContext.delete(item)
                        try? modelContext.save()
                        selectedWatchlistItem = nil
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
    }
    
    // MARK: - Home Scroll View
    
    private var homeScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Watchlist (if any)
                if !watchlistItems.isEmpty {
                    watchlistSection
                }
                
                // Smart Collections
                SmartCollectionsSection(seenItems: seenItems)
                
                // My Lists
                MyListsSection()
                
                // Recently Added
                recentlyAddedSection
                
                // View All
                NavigationLink {
                    FilteredGridView(
                        title: "All Seen",
                        items: seenItems,
                        initialFilter: .all
                    )
                } label: {
                    HStack {
                        Text("View All")
                            .font(.body.weight(.semibold))
                        Text("(\(seenItems.count))")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Watchlist Section
    
    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Watchlist")
                    .font(.title3.weight(.bold))
                
                Text("\(watchlistItems.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                NavigationLink {
                    WatchlistGridView(items: watchlistItems)
                } label: {
                    Text("See All")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(watchlistItems.prefix(15)) { item in
                        WatchlistItemCard(item: item)
                            .onTapGesture {
                                selectedWatchlistItem = item
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Recently Added Section
    
    private var recentlyAddedSection: some View {
        let recentItems = Array(seenItems.prefix(10))
        
        return Group {
            if !recentItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recently Added")
                        .font(.title3.weight(.bold))
                        .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(recentItems) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    RetryAsyncImage(url: item.thumbnailURL)
                                        .aspectRatio(2/3, contentMode: .fit)
                                        .frame(width: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    Text(item.title)
                                        .font(.caption2.weight(.medium))
                                        .lineLimit(1)
                                        .frame(width: 90, alignment: .leading)
                                }
                                .onTapGesture {
                                    selectedItem = item
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
    
    // MARK: - Search Results
    
    private var searchResultsView: some View {
        let filtered = seenItems.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        
        return Group {
            if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filtered) { item in
                            SeenItemCard(item: item)
                                .onTapGesture {
                                    selectedItem = item
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }
    
    // MARK: - List Detail (resolved from entries)
    
    private func listDetailView(for list: UserList) -> some View {
        let listItems = list.items(entries: allEntries, allItems: seenItems)
        return FilteredGridView(
            title: list.name,
            items: listItems,
            initialFilter: .all,
            listName: list.name,
            sourceList: list
        )
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Movies Yet")
                .font(.title2.weight(.semibold))
            
            Text("Start swiping to build your\nlibrary and watchlist!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    AlreadySeenHomeView()
        .modelContainer(for: [SwipedItem.self, UserList.self, ListEntry.self], inMemory: true)
}
