import SwiftUI
import SwiftData

/// Reusable filtered grid view used by smart collections, list details, and "View All"
struct FilteredGridView: View {
    let title: String
    let items: [SwipedItem]
    let initialFilter: SeenFilter
    var listName: String? = nil  // Non-nil when showing a user list (used for share text)
    var sourceList: UserList? = nil  // Non-nil when viewing a list (enables bulk add, remove from list)
    
    @Query(filter: #Predicate<SwipedItem> {
        $0.swipeDirection == "seen" || $0.swipeDirection == "watchlist"
    },
           sort: \SwipedItem.dateSwiped, order: .reverse)
    private var allLibraryItems: [SwipedItem]
    @Query private var allEntries: [ListEntry]
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var ratingFilter: Int?
    @State private var genreFilter: Int?
    @State private var typeFilter: MediaItem.MediaType?
    @State private var searchText = ""
    @State private var selectedItem: SwipedItem?
    @State private var addToListItem: SwipedItem?
    @State private var showBulkAdd = false
    @State private var isEditing = false
    @State private var selectedItemIDs: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var showBulkAddSelected = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    /// When viewing a list, items come from live entries; otherwise use passed-in items.
    private var effectiveItems: [SwipedItem] {
        if let list = sourceList {
            let entryItemIDs = Set(allEntries.filter { $0.listID == list.id }.map(\.itemID))
            return allLibraryItems.filter { entryItemIDs.contains($0.uniqueID) }
        } else {
            return items
        }
    }
    
    // Compute from the effective item set (unfiltered)
    private var availableRatings: [Int] {
        let ratings = Set(effectiveItems.compactMap(\.personalRating))
        return [5, 4, 3, 2, 1].filter { ratings.contains($0) }
    }
    
    private var availableGenres: [(id: Int, name: String)] {
        var genreCounts: [Int: Int] = [:]
        for item in effectiveItems {
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
        let types = Set(effectiveItems.map(\.mediaTypeEnum))
        return types.count > 1 ? [.movie, .tvShow] : []
    }
    
    private var displayedItems: [SwipedItem] {
        var result = effectiveItems
        
        // Apply initial filter
        switch initialFilter {
        case .favorites:
            result = result.filter { ($0.personalRating ?? 0) >= 4 }
        case .movies:
            result = result.filter { $0.mediaTypeEnum == .movie }
        case .tvShows:
            result = result.filter { $0.mediaTypeEnum == .tvShow }
        case .genre(let id):
            result = result.filter { $0.genreIDs.contains(id) }
        case .platform(let name):
            result = result.filter { $0.sourcePlatform == name }
        case .recentlyAdded:
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            result = result.filter { $0.dateSwiped >= thirtyDaysAgo }
        case .all:
            break
        }
        
        // Additional filters
        if let ratingFilter {
            result = result.filter { $0.personalRating == ratingFilter }
        }
        if let genreFilter {
            result = result.filter { $0.genreIDs.contains(genreFilter) }
        }
        if let typeFilter {
            result = result.filter { $0.mediaTypeEnum == typeFilter }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
    
    // MARK: - Share Text
    
    private var shareText: String {
        let header: String
        if let listName {
            header = "\u{1F4CB} \(listName)"
        } else {
            header = "\u{1F3AC} My \(title)"
        }
        
        let itemLines = displayedItems.prefix(50).map { item in
            var line = "\u{2022} \(item.title)"
            if let year = item.releaseYear { line += " (\(year))" }
            if let rating = item.personalRating {
                line += " " + String(repeating: "\u{2B50}", count: rating)
            }
            return line
        }.joined(separator: "\n")
        
        var text = "\(header)\n\n\(itemLines)"
        if displayedItems.count > 50 {
            text += "\n...and \(displayedItems.count - 50) more"
        }
        text += "\n\nShared from FlickSwiper"
        return text
    }
    
    /// Share text for currently selected items (edit mode bottom bar).
    private var selectedShareText: String {
        let items = displayedItems.filter { selectedItemIDs.contains($0.uniqueID) }
        let header: String
        if let list = sourceList {
            header = "\u{1F4CB} \(list.name)"
        } else {
            header = "\u{1F3AC} My Picks"
        }
        let lines = items.prefix(50).map { item in
            var line = "\u{2022} \(item.title)"
            if let year = item.releaseYear { line += " (\(year))" }
            if let rating = item.personalRating {
                line += " " + String(repeating: "\u{2B50}", count: rating)
            }
            return line
        }.joined(separator: "\n")
        var text = "\(header)\n\n\(lines)"
        if items.count > 50 {
            text += "\n...and \(items.count - 50) more"
        }
        text += "\n\nShared from FlickSwiper"
        return text
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter chips bar
            filterBar
            
            if displayedItems.isEmpty {
                ContentUnavailableView("No Items", systemImage: "film",
                                       description: Text("No items match your filters."))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(displayedItems) { item in
                            if isEditing {
                                SelectableItemCard(
                                    item: item,
                                    isSelected: selectedItemIDs.contains(item.uniqueID)
                                )
                                .onTapGesture {
                                    if selectedItemIDs.contains(item.uniqueID) {
                                        selectedItemIDs.remove(item.uniqueID)
                                    } else {
                                        selectedItemIDs.insert(item.uniqueID)
                                    }
                                }
                            } else {
                                SeenItemCard(item: item)
                                    .overlay(alignment: .topLeading) {
                                        if item.isWatchlist {
                                            Image(systemName: "bookmark.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.white)
                                                .padding(3)
                                                .background(.blue, in: RoundedRectangle(cornerRadius: 3))
                                                .padding(6)
                                        }
                                    }
                                    .onTapGesture {
                                        selectedItem = item
                                    }
                                    .contextMenu {
                                        contextMenuItems(for: item)
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search titles...")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button {
                        if selectedItemIDs.count == displayedItems.count {
                            selectedItemIDs.removeAll()
                        } else {
                            selectedItemIDs = Set(displayedItems.map(\.uniqueID))
                        }
                    } label: {
                        if selectedItemIDs.count == displayedItems.count {
                            Text("Deselect All")
                        } else {
                            Text("Select All")
                        }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button("Done") {
                        isEditing = false
                        selectedItemIDs.removeAll()
                    }
                    .fontWeight(.semibold)
                } else {
                    Menu {
                        Button {
                            isEditing = true
                        } label: {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                        ShareLink(item: shareText) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isEditing {
                HStack {
                    ShareLink(item: selectedShareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body)
                    }
                    .disabled(selectedItemIDs.isEmpty)
                    
                    Spacer()
                    
                    if sourceList == nil {
                        Button {
                            showBulkAddSelected = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.body)
                        }
                        .disabled(selectedItemIDs.isEmpty)
                        
                        Spacer()
                    }
                    
                    Text("\(selectedItemIDs.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.body)
                    }
                    .disabled(selectedItemIDs.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if sourceList != nil && !isEditing {
                Button {
                    showBulkAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(.blue, in: Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                .padding(20)
            }
        }
        .sheet(isPresented: $showBulkAdd) {
            if let list = sourceList {
                BulkAddToListView(list: list)
            }
        }
        .sheet(item: $selectedItem) { item in
            SeenItemDetailView(item: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $addToListItem) { item in
            AddToListSheet(item: item)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBulkAddSelected) {
            AddSelectedToListSheet(itemIDs: selectedItemIDs)
        }
        .alert(
            sourceList != nil ? "Remove from List?" : "Delete from Library?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) { }
            Button(
                sourceList != nil ? "Remove" : "Delete",
                role: .destructive
            ) {
                performBulkDelete()
            }
        } message: {
            if sourceList != nil {
                Text("Remove \(selectedItemIDs.count) item(s) from \"\(sourceList?.name ?? "")\"? They'll still be in your library.")
            } else {
                Text("Delete \(selectedItemIDs.count) item(s) permanently? This cannot be undone.")
            }
        }
    }
    
    // MARK: - Filter Bar
    
    @ViewBuilder
    private var filterBar: some View {
        if !availableRatings.isEmpty || !availableGenres.isEmpty || !availableTypes.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Rating chips
                    ForEach(availableRatings, id: \.self) { stars in
                        FilterChip(
                            label: String(repeating: "\u{2605}", count: stars),
                            isActive: ratingFilter == stars,
                            action: { ratingFilter = ratingFilter == stars ? nil : stars }
                        )
                    }
                    
                    if !availableRatings.isEmpty && !availableTypes.isEmpty {
                        Divider().frame(height: 20)
                    }
                    
                    // Type chips
                    ForEach(availableTypes, id: \.self) { type in
                        FilterChip(
                            label: type == .movie ? "Movies" : "TV Shows",
                            isActive: typeFilter == type,
                            action: { typeFilter = typeFilter == type ? nil : type }
                        )
                    }
                    
                    if !availableGenres.isEmpty && (!availableRatings.isEmpty || !availableTypes.isEmpty) {
                        Divider().frame(height: 20)
                    }
                    
                    // Genre chips
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
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func contextMenuItems(for item: SwipedItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            Label("View Details", systemImage: "info.circle")
        }
        
        if let list = sourceList {
            Button(role: .destructive) {
                removeFromList(item: item, list: list)
            } label: {
                Label("Remove from List", systemImage: "minus.circle")
            }
        } else {
            Button {
                addToListItem = item
            } label: {
                Label("Add to List", systemImage: "text.badge.plus")
            }
        }
    }
    
    private func removeFromList(item: SwipedItem, list: UserList) {
        if let entry = allEntries.first(where: { $0.listID == list.id && $0.itemID == item.uniqueID }) {
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }
    
    private func performBulkDelete() {
        if let list = sourceList {
            let entriesToDelete = allEntries.filter {
                $0.listID == list.id && selectedItemIDs.contains($0.itemID)
            }
            for entry in entriesToDelete {
                modelContext.delete(entry)
            }
        } else {
            let relatedEntries = allEntries.filter { selectedItemIDs.contains($0.itemID) }
            for entry in relatedEntries {
                modelContext.delete(entry)
            }
            let itemsToDelete = allLibraryItems.filter { selectedItemIDs.contains($0.uniqueID) }
            for item in itemsToDelete {
                modelContext.delete(item)
            }
        }
        try? modelContext.save()
        selectedItemIDs.removeAll()
        isEditing = false
    }
    
}
