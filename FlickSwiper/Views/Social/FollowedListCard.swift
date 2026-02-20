import SwiftUI

/// Card for a followed list, shown in the "Following" horizontal scroll section.
/// Displays list name, owner attribution, item count, and first poster thumbnail.
struct FollowedListCard: View {
    let followedList: FollowedList
    let firstPosterPath: String?
    
    var body: some View {
        HStack(spacing: 12) {
            // Poster thumbnail
            if let posterPath = firstPosterPath,
               let url = URL(string: "https://image.tmdb.org/t/p/w185\(posterPath)") {
                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.gray.opacity(0.2))
                }
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.gray.opacity(0.2))
                    .frame(width: 50, height: 75)
                    .overlay {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(.secondary)
                    }
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(followedList.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                
                Text("by \(followedList.ownerDisplayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 4) {
                    Text("\(followedList.itemCount) items")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if !followedList.isActive {
                        Text("· Unavailable")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 200, alignment: .leading)
        .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(followedList.name) by \(followedList.ownerDisplayName), \(followedList.itemCount) items\(followedList.isActive ? "" : ", no longer available")")
        .accessibilityAddTraits(.isButton)
    }
}
