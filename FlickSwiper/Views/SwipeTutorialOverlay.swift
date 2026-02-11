import SwiftUI

/// First-launch swipe tutorial overlay (Tinder/Bumble style).
/// Steps through right → left → up swipe instructions, then dismisses.
struct SwipeTutorialOverlay: View {
    let onDismiss: () -> Void

    @State private var currentStep = 0
    @State private var arrowOffset: CGFloat = 0
    @State private var isPulsing = false

    private let steps: [(direction: String, symbol: String, label: String, subtitle: String, color: Color, angle: Angle, arrowAxis: Axis)] = [
        ("→", "checkmark.circle.fill", "Swipe Right", "Already seen it", .green, .degrees(0), .horizontal),
        ("←", "xmark.circle.fill", "Swipe Left", "Not interested, skip", .gray, .degrees(180), .horizontal),
        ("↑", "bookmark.circle.fill", "Swipe Up", "Save to watchlist", .blue, .degrees(-90), .vertical),
    ]

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { advance() }

            VStack(spacing: 32) {
                Spacer()

                // Animated directional arrow
                arrowView
                    .frame(height: 120)

                // Icon + Text
                VStack(spacing: 12) {
                    Image(systemName: steps[currentStep].symbol)
                        .font(.system(size: 52))
                        .foregroundStyle(steps[currentStep].color)
                        .symbolEffect(.pulse, options: .repeating, value: isPulsing)

                    Text(steps[currentStep].label)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)

                    Text(steps[currentStep].subtitle)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentStep ? steps[currentStep].color : .white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                // Bottom button
                Button {
                    advance()
                } label: {
                    Text(currentStep < steps.count - 1 ? "Next" : "Got it!")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(currentStep < steps.count - 1 ? .black : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            currentStep < steps.count - 1
                                ? AnyShapeStyle(Color.white)
                                : AnyShapeStyle(steps[currentStep].color),
                            in: Capsule()
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 16)

                // Skip link
                if currentStep < steps.count - 1 {
                    Button("Skip tutorial") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            isPulsing = true
            startArrowAnimation()
        }
        .onChange(of: currentStep) { _, _ in
            arrowOffset = 0
            startArrowAnimation()
        }
    }

    // MARK: - Arrow

    @ViewBuilder
    private var arrowView: some View {
        let step = steps[currentStep]

        if step.arrowAxis == .horizontal {
            // Horizontal arrow (right or left)
            let isRight = currentStep == 0
            HStack(spacing: 4) {
                if !isRight {
                    Image(systemName: "chevron.left")
                        .font(.title.weight(.bold))
                        .foregroundStyle(step.color)
                }
                Image(systemName: "hand.point.up.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.8))
                    .rotationEffect(.degrees(isRight ? 90 : -90))
                if isRight {
                    Image(systemName: "chevron.right")
                        .font(.title.weight(.bold))
                        .foregroundStyle(step.color)
                }
            }
            .offset(x: isRight ? arrowOffset : -arrowOffset)
        } else {
            // Vertical arrow (up)
            VStack(spacing: 4) {
                Image(systemName: "chevron.up")
                    .font(.title.weight(.bold))
                    .foregroundStyle(step.color)
                Image(systemName: "hand.point.up.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .offset(y: -arrowOffset)
        }
    }

    // MARK: - Helpers

    private func startArrowAnimation() {
        withAnimation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true)
        ) {
            arrowOffset = 20
        }
    }

    private func advance() {
        if currentStep < steps.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
        } else {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            onDismiss()
        }
    }
}

#Preview {
    SwipeTutorialOverlay(onDismiss: {})
}
