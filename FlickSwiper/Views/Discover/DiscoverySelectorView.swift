import SwiftUI

/// A minimalistic selector for discovery methods
struct DiscoverySelectorView: View {
    @Binding var selectedMethod: DiscoveryMethod
    @Binding var contentTypeFilter: ContentTypeFilter
    @Binding var yearFilterMin: Int?
    @Binding var yearFilterMax: Int?
    @Binding var selectedGenre: Genre?
    @Binding var selectedSort: StreamingSortOption

    @State private var showingMethodPicker = false
    @State private var showingFilters = false

    private var isYearFilterActive: Bool {
        yearFilterMin != nil || yearFilterMax != nil
    }

    private var isGenreFilterActive: Bool {
        selectedGenre != nil
    }

    private var hasActiveFilters: Bool {
        isGenreFilterActive || isYearFilterActive || selectedSort != .popular
    }

    var body: some View {
        HStack(spacing: 8) {
            // Discovery method button
            Button {
                showingMethodPicker = true
            } label: {
                HStack(spacing: 6) {
                    if let logoURL = selectedMethod.logoURL {
                        AsyncImage(url: logoURL) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Image(systemName: selectedMethod.iconName.isEmpty ? "tv.fill" : selectedMethod.iconName)
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Image(systemName: selectedMethod.iconName.isEmpty ? "tv.fill" : selectedMethod.iconName)
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(selectedMethod.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()

            // Content type inline chips
            ForEach(ContentTypeFilter.allCases) { filter in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        contentTypeFilter = filter
                    }
                } label: {
                    Text(filter.shortLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(contentTypeFilter == filter ? .black : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            contentTypeFilter == filter ? Color.accentColor : Color.gray.opacity(0.15),
                            in: Capsule()
                        )
                }
            }

            // Filter button with active badge
            Button {
                showingFilters = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(hasActiveFilters ? .black : .secondary)
                    .padding(10)
                    .background(
                        hasActiveFilters ? Color.accentColor : Color.gray.opacity(0.15),
                        in: Circle()
                    )
            }
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $showingMethodPicker) {
            DiscoveryMethodPicker(selectedMethod: $selectedMethod)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingFilters) {
            DiscoverFiltersSheet(
                selectedSort: $selectedSort,
                selectedGenre: $selectedGenre,
                yearFilterMin: $yearFilterMin,
                yearFilterMax: $yearFilterMax,
                showSort: selectedMethod.watchProviderID != nil
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Preview

#Preview("Selector") {
    VStack {
        DiscoverySelectorView(
            selectedMethod: .constant(.popular),
            contentTypeFilter: .constant(.all),
            yearFilterMin: .constant(nil),
            yearFilterMax: .constant(nil),
            selectedGenre: .constant(nil),
            selectedSort: .constant(.popular)
        )
        Spacer()
    }
    .padding(.top)
}
