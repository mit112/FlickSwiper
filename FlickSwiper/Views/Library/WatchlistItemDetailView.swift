import SwiftUI

/// Detail view for a watchlist item — shows overview, rating, and "I've Watched This" action
struct WatchlistItemDetailView: View {
    let item: SwipedItem
    let onMarkAsSeen: () -> Void
    let onRemove: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    
                    HStack {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(.blue)
                        Text("Saved to watchlist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.dateSwiped, style: .date)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 10) {
                        Button {
                            onMarkAsSeen()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("I've Watched This")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                        }
                        
                        Button(role: .destructive) {
                            onRemove()
                        } label: {
                            HStack {
                                Image(systemName: "bookmark.slash")
                                Text("Remove from Watchlist")
                            }
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal)
                    
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
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            RetryAsyncImage(url: item.posterURL)
                .frame(width: 120, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: item.mediaTypeEnum == .movie ? "film" : "tv")
                        .font(.caption2.weight(.semibold))
                    Text(item.mediaTypeEnum.displayName)
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
    }
}

