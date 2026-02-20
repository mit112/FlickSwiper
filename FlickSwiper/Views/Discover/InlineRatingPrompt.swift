import SwiftUI

/// Rating prompt shown inline after swiping right, before the next card appears
struct InlineRatingPrompt: View {
    let itemTitle: String
    let onRate: (Int) -> Void
    let onSkip: () -> Void
    
    @State private var selectedRating: Int = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("How was it?")
                .font(.title3.weight(.semibold))
            
            Text(itemTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            HStack(spacing: 16) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                            selectedRating = star
                        }
                        HapticManager.selectionChanged()
                        // Small delay so user sees the fill before dismissal
                        Task {
                            try? await Task.sleep(for: .seconds(0.3))
                            onRate(star)
                        }
                    } label: {
                        Image(systemName: "star.fill")
                            .font(.title)
                            .foregroundStyle(
                                star <= selectedRating ? .yellow : .yellow.opacity(0.3)
                            )
                            .scaleEffect(star <= selectedRating ? 1.15 : 0.9)
                            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: selectedRating)
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
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
