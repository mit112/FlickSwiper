import SwiftUI
import SwiftData

/// View displaying the list of movies and TV shows marked as "Already Seen"
struct SeenListView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(filter: #Predicate<SwipedItem> { $0.swipeDirection == "seen" },
           sort: \SwipedItem.dateSwiped, order: .reverse)
    private var seenItems: [SwipedItem]
    
    @State private var searchText = ""
    @State private var selectedItem: SwipedItem?
    @State private var filterType: MediaItem.MediaType?
    
    private var filteredItems: [SwipedItem] {
        var items = seenItems
        
        // Filter by media type
        if let filterType = filterType {
            items = items.filter { $0.mediaTypeEnum == filterType }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return items
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if seenItems.isEmpty {
                    emptyStateView
                } else if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    contentView
                }
            }
            .navigationTitle("Already Seen")
            .searchable(text: $searchText, prompt: "Search titles...")
            .toolbar {
                if !seenItems.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        filterMenu
                    }
                }
            }
            .sheet(item: $selectedItem) { item in
                SeenItemDetailView(item: item)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredItems) { item in
                    SeenItemCard(item: item)
                        .onTapGesture {
                            selectedItem = item
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .animation(.default, value: filteredItems.count)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Movies Yet")
                .font(.title2.weight(.semibold))
            
            Text("Start swiping to build your\n\"Already Seen\" collection!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Filter Menu
    
    private var filterMenu: some View {
        Menu {
            Button {
                withAnimation { filterType = nil }
            } label: {
                Label("All", systemImage: filterType == nil ? "checkmark.circle.fill" : "circle")
            }
            
            Divider()
            
            Button {
                withAnimation { filterType = .movie }
            } label: {
                Label("Movies Only", systemImage: filterType == .movie ? "checkmark.circle.fill" : "circle")
            }
            
            Button {
                withAnimation { filterType = .tvShow }
            } label: {
                Label("TV Shows Only", systemImage: filterType == .tvShow ? "checkmark.circle.fill" : "circle")
            }
        } label: {
            Image(systemName: filterType == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .font(.body)
        }
    }
}

// MARK: - Seen Item Card

struct SeenItemCard: View {
    let item: SwipedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Poster (thumbnail URL; RetryAsyncImage retries on failure, prefetch warms w185 cache)
            RetryAsyncImage(url: item.thumbnailURL)
            .aspectRatio(2/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Title
            Text(item.title)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .foregroundStyle(.primary)
            
            // Metadata
            HStack(spacing: 4) {
                // Media type icon
                Image(systemName: item.mediaTypeEnum == .movie ? "film" : "tv")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                if let year = item.releaseYear {
                    Text(year)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let rating = item.ratingText {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow)
                        Text(rating)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.mediaTypeEnum.displayName), \(item.releaseYear ?? "Unknown year")")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Seen Item Detail View

struct SeenItemDetailView: View {
    let item: SwipedItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showAddToList = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with poster
                    HStack(alignment: .top, spacing: 16) {
                        RetryAsyncImage(url: item.posterURL)
                            .frame(width: 120, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            // Media type badge
                            HStack(spacing: 4) {
                                Image(systemName: item.mediaTypeEnum == .movie ? "film" : "tv")
                                    .font(.caption2.weight(.semibold))
                                Text(item.mediaTypeEnum.displayName)
                                    .font(.caption2.weight(.semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.gray.opacity(0.15), in: Capsule())
                            
                            // Title
                            Text(item.title)
                                .font(.title3.weight(.bold))
                            
                            // Year
                            if let year = item.releaseYear {
                                Text(year)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Rating
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
                            
                            // Date seen
                            Text("Marked as seen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.dateSwiped, style: .date)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Your Rating
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Rating")
                            .font(.headline)
                        
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    if item.personalRating == star {
                                        item.personalRating = nil // tap same star to clear
                                    } else {
                                        item.personalRating = star
                                    }
                                    try? modelContext.save()
                                    HapticManager.selectionChanged()
                                } label: {
                                    Image(systemName: star <= (item.personalRating ?? 0) ? "star.fill" : "star")
                                        .font(.title3)
                                        .foregroundStyle(star <= (item.personalRating ?? 0) ? .yellow : .gray.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Overview
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
                    
                    // Add to List button
                    Button {
                        showAddToList = true
                    } label: {
                        Label("Add to List", systemImage: "text.badge.plus")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAddToList) {
                AddToListSheet(item: item)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Previews

#Preview("List View") {
    SeenListView()
        .modelContainer(for: [SwipedItem.self], inMemory: true)
}

#Preview("Item Card") {
    SeenItemCard(
        item: {
            let item = SwipedItem(from: MediaItem(
                id: 1,
                title: "Inception",
                overview: "A mind-bending thriller",
                posterPath: "/8IB2e4r4oVhHnANbnm7O3Tj6tF8.jpg",
                releaseDate: "2010-07-16",
                rating: 8.4,
                mediaType: .movie
            ), direction: .seen)
            return item
        }()
    )
    .frame(width: 120)
    .padding()
}
