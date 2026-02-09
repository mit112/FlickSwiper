import SwiftUI

struct DiscoverFiltersSheet: View {
    @Binding var selectedSort: StreamingSortOption
    @Binding var selectedGenre: Genre?
    @Binding var yearFilterMin: Int?
    @Binding var yearFilterMax: Int?

    let showSort: Bool

    @Environment(\.dismiss) private var dismiss

    private var hasActiveFilters: Bool {
        selectedGenre != nil || yearFilterMin != nil || yearFilterMax != nil || selectedSort != .popular
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Sort section (streaming only)
                    if showSort {
                        sortSection
                    }

                    // Genre section
                    genreSection

                    // Year section
                    yearSection

                    // Clear all
                    if hasActiveFilters {
                        Button {
                            clearAll()
                        } label: {
                            Text("Clear All Filters")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sort Section

    private var sortSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sort by")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StreamingSortOption.allCases) { option in
                        Button {
                            selectedSort = option
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: option.icon)
                                    .font(.caption2.weight(.semibold))
                                Text(option.rawValue)
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(selectedSort == option ? .white : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedSort == option ? Color.blue : Color.gray.opacity(0.15),
                                in: Capsule()
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Genre Section

    private var genreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Genre")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)

                if selectedGenre != nil {
                    Button {
                        selectedGenre = nil
                    } label: {
                        Text("Clear")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Genre.allCases) { genre in
                        Button {
                            if selectedGenre == genre {
                                selectedGenre = nil
                            } else {
                                selectedGenre = genre
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: genre.iconName)
                                    .font(.caption2.weight(.semibold))
                                Text(genre.name)
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(selectedGenre == genre ? .white : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                selectedGenre == genre ? Color.orange : Color.gray.opacity(0.15),
                                in: Capsule()
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Year Section

    private var yearSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Year Range")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)

                if yearFilterMin != nil || yearFilterMax != nil {
                    Button {
                        yearFilterMin = nil
                        yearFilterMax = nil
                    } label: {
                        Text("Clear")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)

            HStack(spacing: 16) {
                // Min year
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Menu {
                        Button("Any") { yearFilterMin = nil }
                        ForEach(yearOptions.reversed(), id: \.self) { year in
                            Button("\(year)") { yearFilterMin = year }
                        }
                    } label: {
                        HStack {
                            Text(yearFilterMin.map { "\($0)" } ?? "Any")
                                .font(.subheadline.weight(.medium))
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                Text("—")
                    .foregroundStyle(.tertiary)

                // Max year
                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Menu {
                        Button("Any") { yearFilterMax = nil }
                        ForEach(yearOptions.reversed(), id: \.self) { year in
                            Button("\(year)") { yearFilterMax = year }
                        }
                    } label: {
                        HStack {
                            Text(yearFilterMax.map { "\($0)" } ?? "Any")
                                .font(.subheadline.weight(.medium))
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Helpers

    private var yearOptions: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(1950...currentYear + 2)
    }

    private func clearAll() {
        selectedSort = .popular
        selectedGenre = nil
        yearFilterMin = nil
        yearFilterMax = nil
    }
}
