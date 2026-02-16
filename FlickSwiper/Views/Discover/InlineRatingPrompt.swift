import SwiftUI

/// Rating prompt shown inline after swiping right, before the next card appears
struct InlineRatingPrompt: View {
    let itemTitle: String
    let onRate: (Int) -> Void
    let onSkip: () -> Void
    
    @State private var selectedRating: Int = 0
    
    var body: some View {
        VStack(spacing: 16) {
            Text("How was it?")
                .font(.headline)
            
            Text(itemTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        selectedRating = star
                        HapticManager.selectionChanged()
                        // Small delay so user sees the fill before dismissal
                        Task {
                            try? await Task.sleep(for: .seconds(0.25))
                            onRate(star)
                        }
                    } label: {
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundStyle(
                                star <= selectedRating ? .yellow : .yellow.opacity(0.3)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Button("Skip") {
                onSkip()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

#Preview {
    InlineRatingPrompt(
        itemTitle: "Inception",
        onRate: { stars in print("Rated \(stars)") },
        onSkip: { print("Skipped") }
    )
}
