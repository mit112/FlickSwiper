import SwiftUI

/// Card for a user-created list, shown in the horizontal scroll
struct UserListCard: View {
    let list: UserList
    let itemCount: Int
    let coverPosterPath: String?  // keep param but unused now
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "list.bullet")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                
                Spacer()
                
                if list.isPublished {
                    Image(systemName: "link")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            
            Spacer()
            
            Text(list.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            
            Text("\(itemCount) items")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(12)
        .frame(width: 140, height: 110, alignment: .leading)
        .background(cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(list.name) list, \(itemCount) items\(list.isPublished ? ", shared" : "")")
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
        let options: [[Color]] = [
            [.orange, .pink.opacity(0.8)],
            [.teal, .blue.opacity(0.8)],
            [.indigo, .purple.opacity(0.8)],
            [.green, .teal.opacity(0.8)],
            [.red, .orange.opacity(0.8)],
            [.purple, .pink.opacity(0.8)],
        ]
        // Stable color based on list name hash
        let index = abs(list.name.hashValue) % options.count
        return options[index]
    }
}
