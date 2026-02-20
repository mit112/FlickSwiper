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
                    .foregroundStyle(Color(.secondaryLabel))
                
                Spacer()
                
                if list.isPublished {
                    Image(systemName: "link")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            
            Spacer()
            
            Text(list.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(.label))
                .lineLimit(2)
            
            Text("\(itemCount) items")
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(12)
        .frame(width: 140, height: 110, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(list.name) list, \(itemCount) items\(list.isPublished ? ", shared" : "")")
        .accessibilityAddTraits(.isButton)
    }
}
