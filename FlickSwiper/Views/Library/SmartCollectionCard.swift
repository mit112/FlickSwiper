import SwiftUI

// MARK: - SmartCollectionCard

/// Individual card in the smart collections horizontal scroll
/// Solid gradients and clear typography — no blurred posters at this size
struct SmartCollectionCard: View {
    let collection: SmartCollection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: collection.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            
            Spacer()
            
            Text(collection.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            
            Text("\(collection.count)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(12)
        .frame(width: 140, height: 110, alignment: .leading)
        .background(cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(collection.title), \(collection.count) items")
        .accessibilityAddTraits(.isButton)
    }
    
    private var cardGradient: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var gradientColors: [Color] {
        switch collection.filter {
        case .favorites:
            return [.pink, .red.opacity(0.8)]
        case .movies:
            return [.blue, .indigo.opacity(0.8)]
        case .tvShows:
            return [.purple, .blue.opacity(0.8)]
        case .genre(let id):
            return genreColors(for: id)
        case .platform(let name):
            return platformColors(for: name)
        case .recentlyAdded:
            return [.orange, .yellow.opacity(0.7)]
        case .all:
            return [.gray, .gray.opacity(0.7)]
        }
    }
    
    private func genreColors(for id: Int) -> [Color] {
        switch id {
        case 28:    return [.red, .orange.opacity(0.8)]           // Action
        case 12:    return [.green, .teal.opacity(0.8)]           // Adventure
        case 16:    return [.mint, .cyan.opacity(0.8)]            // Animation
        case 35:    return [.yellow, .orange.opacity(0.8)]        // Comedy
        case 80:    return [.gray, .brown.opacity(0.8)]           // Crime
        case 99:    return [.teal, .blue.opacity(0.8)]            // Documentary
        case 18:    return [.indigo, .purple.opacity(0.8)]        // Drama
        case 10751: return [.green, .mint.opacity(0.8)]          // Family
        case 14:    return [.purple, .pink.opacity(0.8)]          // Fantasy
        case 27:    return [.black, .red.opacity(0.6)]            // Horror
        case 9648:  return [.indigo, .gray.opacity(0.8)]          // Mystery
        case 10749: return [.pink, .red.opacity(0.7)]            // Romance
        case 878:   return [.cyan, .blue.opacity(0.8)]            // Sci-Fi
        case 53:    return [.gray, .red.opacity(0.6)]             // Thriller
        default:    return [.blue.opacity(0.7), .purple.opacity(0.6)]
        }
    }
    
    private func platformColors(for name: String) -> [Color] {
        switch name.lowercased() {
        case let n where n.contains("netflix"):     return [.red, .red.opacity(0.7)]
        case let n where n.contains("disney"):     return [.blue, .indigo.opacity(0.8)]
        case let n where n.contains("prime"):      return [.cyan, .blue.opacity(0.8)]
        case let n where n.contains("apple"):      return [.gray, .black.opacity(0.8)]
        case let n where n.contains("hulu"):       return [.green, .green.opacity(0.7)]
        case let n where n.contains("max"):        return [.purple, .blue.opacity(0.8)]
        case let n where n.contains("paramount"):  return [.blue, .cyan.opacity(0.8)]
        case let n where n.contains("peacock"):    return [.yellow, .green.opacity(0.7)]
        case let n where n.contains("hbo"):        return [.purple, .indigo.opacity(0.8)]
        default:                                  return [.blue.opacity(0.7), .purple.opacity(0.6)]
        }
    }
}

#Preview {
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
}
