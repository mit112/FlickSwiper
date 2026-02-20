import SwiftUI

/// AsyncImage wrapper that retries on failure so transient network issues don't leave placeholders.
/// Includes a shimmer loading state and fade-in on image load.
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
                ShimmerView()
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            case .failure:
                if attempts < maxRetries {
                    ShimmerView()
                        .onAppear {
                            attempts += 1
                            // Force AsyncImage to retry by changing its identity
                            Task {
                                try? await Task.sleep(for: .seconds(1.0))
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

// MARK: - Shimmer Loading Effect

/// Animated shimmer placeholder for loading images
private struct ShimmerView: View {
    @State private var phase: CGFloat = -1.0
    
    var body: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .overlay {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.08),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: phase * 200)
            }
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 1.2)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1.0
                }
            }
    }
}
