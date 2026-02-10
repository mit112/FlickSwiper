import SwiftUI

/// Detail sheet for a title in Discover — read overview and choose Seen or Skip
struct DiscoverDetailView: View {
    let item: MediaItem
    let onSeen: () -> Void
    let onSkip: () -> Void
    let onSaveToWatchlist: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

                    VStack(spacing: 10) {
                        // Primary row: Skip and Seen
                        HStack(spacing: 12) {
                            Button {
                                onSkip()
                            } label: {
                                HStack {
                                    Image(systemName: "xmark")
                                    Text("Skip")
                                }
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.secondary)
                            }

                            Button {
                                onSeen()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Seen")
                                }
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.green, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                            }
                        }

                        // Secondary: Save for Later (full width)
                        Button {
                            onSaveToWatchlist()
                        } label: {
                            HStack {
                                Image(systemName: "bookmark.fill")
                                Text("Save for Later")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
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
    }
}
