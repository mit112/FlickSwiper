import SwiftUI

/// Discovery method picker sheet
struct DiscoveryMethodPicker: View {
    @Binding var selectedMethod: DiscoveryMethod
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(DiscoveryMethod.grouped, id: \.category) { group in
                    Section(group.category.rawValue) {
                        ForEach(group.methods) { method in
                            MethodRowButton(
                                method: method,
                                isSelected: method == selectedMethod,
                                onTap: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedMethod = method
                                    }
                                    dismiss()
                                }
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Method Row Button

private struct MethodRowButton: View {
    let method: DiscoveryMethod
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                iconView
                
                Text(method.rawValue)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var iconView: some View {
        let symbolName = method.iconName.isEmpty ? "tv.fill" : method.iconName
        if let logoURL = method.logoURL {
            AsyncImage(url: logoURL) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: symbolName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isSelected ? .black : .primary)
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .background(
                isSelected ? Color.accentColor : Color.gray.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 8)
            )
        } else {
            Image(systemName: symbolName)
                .font(.body.weight(.medium))
                .foregroundStyle(isSelected ? .black : .primary)
                .frame(width: 32, height: 32)
                .background(
                    isSelected ? Color.accentColor : Color.gray.opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
    }
}

// MARK: - Compact Horizontal Selector (Alternative)

struct DiscoveryHorizontalSelector: View {
    @Binding var selectedMethod: DiscoveryMethod
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DiscoveryMethod.allCases) { method in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedMethod = method
                        }
                    } label: {
                        HStack(spacing: 6) {
                            let symbolName = method.iconName.isEmpty ? "tv.fill" : method.iconName
                            if let logoURL = method.logoURL {
                                AsyncImage(url: logoURL) { image in
                                    image.resizable().aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    Image(systemName: symbolName)
                                        .font(.caption.weight(.semibold))
                                }
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Image(systemName: symbolName)
                                    .font(.caption.weight(.semibold))
                            }
                            Text(method.rawValue)
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            method == selectedMethod
                                ? Color.accentColor
                                : Color.gray.opacity(0.15),
                            in: Capsule()
                        )
                        .foregroundStyle(method == selectedMethod ? .black : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Previews

#Preview("Picker Sheet") {
    DiscoveryMethodPicker(selectedMethod: .constant(.popular))
}

#Preview("Horizontal Selector") {
    DiscoveryHorizontalSelector(selectedMethod: .constant(.popular))
}
