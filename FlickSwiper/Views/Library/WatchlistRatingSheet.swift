import SwiftUI
import SwiftData
import os

/// Rating sheet presented after marking a watchlist item as seen — converts watchlist → seen with a star rating
struct WatchlistRatingSheet: View {
    let item: SwipedItem
    let onDismiss: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "WatchlistRating")
    @State private var persistenceErrorMessage: String?
    
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
                            do {
                                try SwipedItemStore(context: modelContext).setPersonalRating(star, for: item)
                                onDismiss()
                            } catch {
                                logger.error("Failed to save watchlist rating: \(error.localizedDescription)")
                                persistenceErrorMessage = "We couldn't save your rating. Please try again."
                            }
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
        .alert(
            "Couldn't Save Changes",
            isPresented: Binding(
                get: { persistenceErrorMessage != nil },
                set: { if !$0 { persistenceErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { persistenceErrorMessage = nil }
        } message: {
            Text(persistenceErrorMessage ?? "Please try again.")
        }
    }
}

