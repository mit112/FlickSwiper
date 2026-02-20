import SwiftUI

/// Reusable capsule-shaped filter chip button
/// Filled when active, outlined when inactive
struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isActive
                        ? AnyShapeStyle(Color.accentColor)
                        : AnyShapeStyle(Color.gray.opacity(0.15)),
                    in: Capsule()
                )
                .foregroundStyle(isActive ? .black : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        FilterChip(label: "Action", isActive: true, action: {})
        FilterChip(label: "Comedy", isActive: false, action: {})
        FilterChip(label: "Drama", isActive: false, action: {})
    }
    .padding()
}
