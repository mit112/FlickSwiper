import SwiftUI
import UIKit

/// A swipeable card view displaying movie/TV show information
struct MovieCardView: View {
    let item: MediaItem
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void
    var onInfoTap: () -> Void
    var onSaveToWatchlist: () -> Void

    /// Whether this is the top card (interactive)
    var isTopCard: Bool = true

    /// Index in the stack (for scale/offset effect)
    var stackIndex: Int = 0

    /// Binding to trigger programmatic swipe
    @Binding var triggerSwipeLeft: Bool
    @Binding var triggerSwipeRight: Bool

    // MARK: - State

    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0

    // MARK: - Constants (from centralized Constants)

    private let swipeThreshold = Constants.Animation.swipeThreshold
    private let maxRotation = Constants.Animation.maxRotation

    init(item: MediaItem,
         onSwipeLeft: @escaping () -> Void,
         onSwipeRight: @escaping () -> Void,
         onInfoTap: @escaping () -> Void = {},
         onSaveToWatchlist: @escaping () -> Void = {},
         isTopCard: Bool = true,
         stackIndex: Int = 0,
         triggerSwipeLeft: Binding<Bool> = .constant(false),
         triggerSwipeRight: Binding<Bool> = .constant(false)) {
        self.item = item
        self.onSwipeLeft = onSwipeLeft
        self.onSwipeRight = onSwipeRight
        self.onInfoTap = onInfoTap
        self.onSaveToWatchlist = onSaveToWatchlist
        self.isTopCard = isTopCard
        self.stackIndex = stackIndex
        self._triggerSwipeLeft = triggerSwipeLeft
        self._triggerSwipeRight = triggerSwipeRight
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Poster Image
                posterImage
                
                // Gradient overlay for text readability
                gradientOverlay
                
                // Info overlay
                infoOverlay
                
                // Swipe indicators
                swipeIndicators
            }
            .overlay {
                if isTopCard {
                    VStack {
                        HStack {
                            // Bookmark — top left
                            Button {
                                onSaveToWatchlist()
                            } label: {
                                Image(systemName: "bookmark.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 4)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Save to watchlist")
                            .offset(x: -6, y: 8)
                            
                            Spacer()
                            
                            // Info — top right
                            Button {
                                onInfoTap()
                            } label: {
                                Image(systemName: "info.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 4)
                            }
                            .buttonStyle(.plain)
                            .offset(x: 6, y: 8)
                        }
                        .padding(20)
                        
                        Spacer()
                    }
                }
            }
            .frame(width: geometry.size.width - 32, height: geometry.size.height - 40)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            .offset(x: isTopCard ? offset.width : 0, y: isTopCard ? offset.height : CGFloat(stackIndex * 8))
            .scaleEffect(isTopCard ? 1.0 : 1.0 - CGFloat(stackIndex) * 0.05)
            .rotationEffect(.degrees(isTopCard ? rotation : 0))
            .gesture(isTopCard ? dragGesture : nil)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: offset)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .onChange(of: triggerSwipeLeft) { _, newValue in
                if newValue && isTopCard {
                    performProgrammaticSwipe(direction: .left)
                }
            }
            .onChange(of: triggerSwipeRight) { _, newValue in
                if newValue && isTopCard {
                    performProgrammaticSwipe(direction: .right)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(cardAccessibilityLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Mark as already seen") { onSwipeRight() }
            .accessibilityAction(named: "Skip") { onSwipeLeft() }
        }
    }
    
    // MARK: - Accessibility
    
    private var cardAccessibilityLabel: String {
        var parts: [String] = [item.title]
        if let year = item.releaseYear { parts.append("released \(year)") }
        parts.append(item.mediaType == .movie ? "Movie" : "TV Show")
        if let rating = item.ratingText { parts.append("rated \(rating) out of 10") }
        return parts.joined(separator: ", ")
    }
    
    // MARK: - Programmatic Swipe
    
    private enum SwipeDirection {
        case left, right
    }
    
    private func performProgrammaticSwipe(direction: SwipeDirection) {
        let targetOffset: CGFloat = direction == .right ? 500 : -500
        let targetRotation = direction == .right ? maxRotation : -maxRotation

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = CGSize(width: targetOffset, height: 0)
            rotation = targetRotation
        }

        if direction == .right {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onSwipeRight()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onSwipeLeft()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var posterImage: some View {
        AsyncImage(url: item.posterURL) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        ProgressView()
                            .tint(.gray)
                    }
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.gray)
                            Text("No Image")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
            @unknown default:
                EmptyView()
            }
        }
    }
    
    private var gradientOverlay: some View {
        LinearGradient(
            colors: [
                .clear,
                .clear,
                .black.opacity(0.3),
                .black.opacity(0.8)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var infoOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()
            
            // Media type badge
            HStack(spacing: 6) {
                Image(systemName: item.mediaType == .movie ? "film" : "tv")
                    .font(.caption2.weight(.semibold))
                Text(item.mediaType.displayName)
                    .font(.caption2.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            
            // Title
            Text(item.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            
            // Year and Rating
            HStack(spacing: 12) {
                if let year = item.releaseYear {
                    Text(year)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
                
                if let rating = item.ratingText {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        Text(rating)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            
            // Overview (truncated)
            if !item.overview.isEmpty {
                Text(item.overview)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(3)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var swipeIndicators: some View {
        ZStack {
            // "SEEN" indicator (right swipe)
            Text("SEEN")
                .font(.title.weight(.black))
                .foregroundStyle(.green)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.green, lineWidth: 4)
                )
                .rotationEffect(.degrees(-20))
                .opacity(rightSwipeProgress)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(30)
            
            // "SKIP" indicator (left swipe)
            Text("SKIP")
                .font(.title.weight(.black))
                .foregroundStyle(.gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.gray, lineWidth: 4)
                )
                .rotationEffect(.degrees(20))
                .opacity(leftSwipeProgress)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(30)
            
            // "SAVE" indicator (up swipe)
            Text("SAVE")
                .font(.title.weight(.black))
                .foregroundStyle(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.blue, lineWidth: 4)
                )
                .opacity(upSwipeProgress)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(30)
        }
    }
    
    // MARK: - Gestures
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { gesture in
                offset = gesture.translation
                // Only rotate for horizontal movement
                rotation = Double(gesture.translation.width / 20)
                    .clamped(to: -maxRotation...maxRotation)
            }
            .onEnded { gesture in
                let width = gesture.translation.width
                let height = gesture.translation.height
                
                // Determine dominant axis
                let isVerticalDominant = abs(height) > abs(width)
                
                if isVerticalDominant && height < -swipeThreshold {
                    // Swipe up - save to watchlist
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = CGSize(width: 0, height: -800)
                    }
                    HapticManager.seen()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onSaveToWatchlist()
                    }
                } else if !isVerticalDominant && width > swipeThreshold {
                    // Swipe right - seen
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = CGSize(width: 500, height: 0)
                        rotation = maxRotation
                    }
                    HapticManager.seen()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onSwipeRight()
                    }
                } else if !isVerticalDominant && width < -swipeThreshold {
                    // Swipe left - skip
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = CGSize(width: -500, height: 0)
                        rotation = -maxRotation
                    }
                    HapticManager.skip()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onSwipeLeft()
                    }
                } else {
                    // Return to center
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        offset = .zero
                        rotation = 0
                    }
                }
            }
    }
    
    // MARK: - Computed Properties
    
    private var rightSwipeProgress: Double {
        guard abs(offset.width) > abs(offset.height) else { return 0 }
        return max(0, min(1, Double(offset.width / swipeThreshold)))
    }
    
    private var leftSwipeProgress: Double {
        guard abs(offset.width) > abs(offset.height) else { return 0 }
        return max(0, min(1, Double(-offset.width / swipeThreshold)))
    }
    
    private var upSwipeProgress: Double {
        // Only show when vertical movement dominates
        guard abs(offset.height) > abs(offset.width) else { return 0 }
        return max(0, min(1, Double(-offset.height / swipeThreshold)))
    }
}

// MARK: - Extensions

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview {
    MovieCardView(
        item: MediaItem(
            id: 1,
            title: "Inception",
            overview: "A thief who steals corporate secrets through the use of dream-sharing technology is given the inverse task of planting an idea into the mind of a C.E.O.",
            posterPath: "/8IB2e4r4oVhHnANbnm7O3Tj6tF8.jpg",
            releaseDate: "2010-07-16",
            rating: 8.4,
            mediaType: .movie
        ),
        onSwipeLeft: { print("Swiped left") },
        onSwipeRight: { print("Swiped right") }
    )
    .frame(height: 600)
    .padding()
}
