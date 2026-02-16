import SwiftUI

/// Genre filter picker view
struct GenreFilterPicker: View {
    @Binding var selectedGenre: Genre?
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Genre.commonGenres) { genre in
                        GenreButton(
                            genre: genre,
                            isSelected: selectedGenre == genre,
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    if selectedGenre == genre {
                                        selectedGenre = nil
                                    } else {
                                        selectedGenre = genre
                                    }
                                }
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Filter by Genre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        selectedGenre = nil
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }
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

// MARK: - Genre Button

private struct GenreButton: View {
    let genre: Genre
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: genre.iconName)
                    .font(.body.weight(.medium))
                Text(genre.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                isSelected ? Color.orange : Color.gray.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    GenreFilterPicker(selectedGenre: .constant(.action))
}
