import SwiftUI
import SwiftData

struct WatchlistRatingSheet: View {
    let item: SwipedItem
    let onDismiss: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Text("How was it?")
                    .font(.title2.weight(.bold))
                
                Text(item.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            item.personalRating = star
                            try? modelContext.save()
                            onDismiss()
                        } label: {
                            Image(systemName: "star.fill")
                                .font(.title)
                                .foregroundStyle(.yellow.opacity(0.3))
                        }
                    }
                }
                
                Button("Skip") {
                    onDismiss()
                }
                .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding()
        }
        .presentationDetents([.height(280)])
    }
}

