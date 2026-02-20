import SwiftUI

/// Poster card with selection state: blue border and checkmark when selected (e.g. for bulk add to list)
struct SelectableItemCard: View {
    let item: SwipedItem
    let isSelected: Bool
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                RetryAsyncImage(url: item.thumbnailURL)
                    .aspectRatio(2/3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    )
                
                Text(item.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .background(Circle().fill(.white).padding(2))
                    .offset(x: -6, y: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(isSelected ? "selected" : "not selected")")
        .accessibilityAddTraits(.isButton)
    }
}
