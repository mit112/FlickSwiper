import SwiftUI
import SwiftData
import os

/// Full-screen sheet to add/remove seen items from a list in bulk. Items already in the list are pre-selected.
struct BulkAddToListView: View {
    let list: UserList
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "BulkAddToList")
    
    @Query(filter: #Predicate<SwipedItem> {
        $0.swipeDirection == "seen" || $0.swipeDirection == "watchlist"
    },
           sort: \SwipedItem.dateSwiped, order: .reverse)
    private var allSeenItems: [SwipedItem]
    
    @Query private var allEntries: [ListEntry]
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedIDs: Set<String> = []
    @State private var searchText = ""
    @State private var ratingFilter: Int?
    @State private var genreFilter: Int?
    @State private var typeFilter: MediaItem.MediaType?
    @State private var originalIDs: Set<String> = []
    @State private var persistenceErrorMessage: String?
    
    private var listEntries: [ListEntry] {
        allEntries.filter { $0.listID == list.id }
    }
    
    private var filteredItems: [SwipedItem] {
        var result = allSeenItems
        if let rating = ratingFilter {
            result = result.filter { $0.personalRating == rating }
        }
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
    
    // Contextual filter values from allSeenItems (same logic as FilteredGridView)
    private var availableRatings: [Int] {
        let ratings = Set(allSeenItems.compactMap(\.personalRating))
        return [5, 4, 3, 2, 1].filter { ratings.contains($0) }
    }
    
    private var availableGenres: [(id: Int, name: String)] {
        var genreCounts: [Int: Int] = [:]
        for item in allSeenItems {
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
        let types = Set(allSeenItems.map(\.mediaTypeEnum))
        return types.count > 1 ? [.movie, .tvShow] : []
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChipsBar
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredItems) { item in
                            SelectableItemCard(
                                item: item,
                                isSelected: selectedIDs.contains(item.uniqueID)
                            )
                            .onTapGesture {
                                toggleSelection(item.uniqueID)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Add to \(list.name)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search titles...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if applyChanges() {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                let existingIDs = Set(listEntries.map(\.itemID))
                selectedIDs = existingIDs
                originalIDs = existingIDs
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
    
    private func toggleSelection(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
    
    @discardableResult
    private func applyChanges() -> Bool {
        do {
            let toAdd = selectedIDs.subtracting(originalIDs)
            let currentEntryIDs = try fetchCurrentItemIDs(for: list.id)
            for itemID in toAdd {
                guard !currentEntryIDs.contains(itemID) else { continue }
                let entry = ListEntry(listID: list.id, itemID: itemID)
                modelContext.insert(entry)
            }

            let toRemove = originalIDs.subtracting(selectedIDs)
            for itemID in toRemove {
                if let entry = listEntries.first(where: { $0.itemID == itemID }) {
                    modelContext.delete(entry)
                }
            }

            try dedupeEntries(for: list.id)
            try modelContext.save()
            // Sync to Firestore if this list is published
            let ctx = modelContext
            let syncList = list
            Task { try? await ListPublisher(context: ctx).syncIfPublished(list: syncList) }
            return true
        } catch {
            logger.error("Failed to apply bulk list changes: \(error.localizedDescription)")
            persistenceErrorMessage = "We couldn't update this list. Please try again."
            return false
        }
    }

    private func fetchCurrentItemIDs(for listID: UUID) throws -> Set<String> {
        let id = listID
        let descriptor = FetchDescriptor<ListEntry>(
            predicate: #Predicate<ListEntry> { $0.listID == id }
        )
        let listEntries = try modelContext.fetch(descriptor)
        return Set(listEntries.map(\.itemID))
    }

    private func dedupeEntries(for listID: UUID) throws {
        let id = listID
        let descriptor = FetchDescriptor<ListEntry>(
            predicate: #Predicate<ListEntry> { $0.listID == id }
        )
        let listEntries = try modelContext.fetch(descriptor)
        var seenItemIDs = Set<String>()
        for entry in listEntries {
            if seenItemIDs.contains(entry.itemID) {
                modelContext.delete(entry)
            } else {
                seenItemIDs.insert(entry.itemID)
            }
        }
    }
    
    @ViewBuilder
    private var filterChipsBar: some View {
        if !availableRatings.isEmpty || !availableGenres.isEmpty || !availableTypes.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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
