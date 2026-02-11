import SwiftUI

/// AsyncImage wrapper that retries on failure so transient network issues don't leave placeholders.
struct RetryAsyncImage: View {
    let url: URL?
    let maxRetries: Int
    
    @State private var attempts = 0
    @State private var id = UUID()
    
    init(url: URL?, maxRetries: Int = 2) {
        self.url = url
        self.maxRetries = maxRetries
    }
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay { ProgressView().scaleEffect(0.7) }
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                if attempts < maxRetries {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay { ProgressView().scaleEffect(0.7) }
                        .onAppear {
                            attempts += 1
                            // Force AsyncImage to retry by changing its identity
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                id = UUID()
                            }
                        }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.gray)
                        }
                }
            @unknown default:
                EmptyView()
            }
        }
        .id(id)
        .onAppear {
            if attempts >= maxRetries {
                // Reset and try again when view reappears (tab switch, scroll back into view)
                attempts = 0
                id = UUID()
            }
        }
    }
}
