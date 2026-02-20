import SwiftUI

/// Compact poster card for watchlist items shown in horizontal scroll and grid layouts
struct WatchlistItemCard: View {
    let item: SwipedItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RetryAsyncImage(url: item.thumbnailURL)
                .aspectRatio(2/3, contentMode: .fit)
                .frame(width: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Text(item.title)
                .font(.caption2.weight(.medium))
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.mediaTypeEnum.displayName), in watchlist")
        .accessibilityAddTraits(.isButton)
    }
}

