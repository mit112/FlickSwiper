import SwiftUI

// MARK: - SmartCollectionCard

/// Individual card in the smart collections horizontal scroll
/// Dark elevated surface with icon differentiation — no saturated gradients
struct SmartCollectionCard: View {
    let collection: SmartCollection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: collection.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(iconColor)
            
            Spacer()
            
            Text(collection.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(.label))
                .lineLimit(2)
            
            Text("\(collection.count)")
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(12)
        .frame(width: 140, height: 110, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(collection.title), \(collection.count) items")
        .accessibilityAddTraits(.isButton)
    }
    
    /// Favorites gets the accent color icon; everything else is secondary
    private var iconColor: Color {
        switch collection.filter {
        case .favorites:
            return Color.accentColor
        default:
            return Color(.secondaryLabel)
        }
    }
}

#Preview {
    HStack {
        SmartCollectionCard(
            collection: SmartCollection(
                id: "favorites",
                title: "My Favorites",
                systemImage: "heart.fill",
                count: 12,
                filter: .favorites,
                coverPosterPath: nil
            )
        )
        SmartCollectionCard(
            collection: SmartCollection(
                id: "movies",
                title: "Movies",
                systemImage: "film",
                count: 5,
                filter: .movies,
                coverPosterPath: nil
            )
        )
    }
    .padding()
    .background(.black)
}
