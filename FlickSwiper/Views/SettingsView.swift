import SwiftUI
import SwiftData
import os

/// Full settings screen with discovery controls, about info, and support links
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "SettingsView")
    
    @AppStorage(Constants.StorageKeys.includeSwipedItems) private var includeSwipedItems: Bool = false
    @AppStorage(Constants.StorageKeys.hasSeenSwipeTutorial) private var hasSeenTutorial = false
    @State private var showResetConfirmation = false
    @State private var resetType: ResetType = .skipped
    @State private var showResetWatchlistConfirmation = false
    
    /// Counts computed on-demand instead of loading all SwipedItem records into memory.
    @State private var swipedCount: Int = 0
    @State private var watchlistCount: Int = 0
    
    enum ResetType {
        case skipped, all
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Discovery Section
                Section {
                    HStack {
                        Text("Total Swiped")
                        Spacer()
                        Text("\(swipedCount)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Watchlist")
                        Spacer()
                        Text("\(watchlistCount)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Statistics")
                }
                
                Section {
                    Toggle("Show Previously Swiped", isOn: $includeSwipedItems)
                } header: {
                    Text("Filters")
                } footer: {
                    Text("Enable this to see titles you've already swiped on. Useful for re-evaluating your choices.")
                }
                
                Section {
                    Button {
                        hasSeenTutorial = false
                    } label: {
                        HStack {
                            Image(systemName: "hand.draw.fill")
                                .foregroundStyle(.blue)
                            Text("Replay Swipe Tutorial")
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Button {
                        resetType = .skipped
                        showResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.orange)
                            Text("Reset Skipped Items")
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Button {
                        resetType = .all
                        showResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                            Text("Reset All Swiped Items")
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    Button {
                        showResetWatchlistConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "bookmark.slash")
                                .foregroundStyle(.red)
                            Text("Clear Watchlist")
                                .foregroundStyle(.primary)
                        }
                    }
                } header: {
                    Text("Reset")
                } footer: {
                    Text("Reset skipped items to see them again. Reset all will clear your entire swipe history.")
                }
                
                // MARK: - About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image("tmdb-logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 16)
                            
                            Text("Powered by TMDB")
                                .font(.subheadline.weight(.medium))
                        }
                        
                        Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("About")
                }
                
                // MARK: - Support Section
                Section {
                    Link(destination: Constants.URLs.privacyPolicy) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(.blue)
                            Text("Privacy Policy")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Link(destination: Constants.URLs.contactEmail) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(.blue)
                            Text("Contact Us")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Support")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                refreshCounts()
            }
            .confirmationDialog(
                resetType == .skipped ? "Reset Skipped Items?" : "Reset All Swiped Items?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(resetType == .skipped ? "Reset Skipped" : "Reset All", role: .destructive) {
                    if resetType == .skipped {
                        resetSkippedItems()
                    } else {
                        resetAllSwipedItems()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(resetType == .skipped
                     ? "This will allow skipped titles to appear again."
                     : "This will allow all previously swiped titles to appear again.")
            }
            .alert("Clear Watchlist?", isPresented: $showResetWatchlistConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    resetWatchlistItems()
                }
            } message: {
                Text("Remove all items from your watchlist. This cannot be undone.")
            }
        }
    }
    
    // MARK: - Statistics
    
    /// Fetch counts from SwiftData without loading full objects into memory.
    private func refreshCounts() {
        do {
            let allDescriptor = FetchDescriptor<SwipedItem>()
            swipedCount = try modelContext.fetchCount(allDescriptor)
            
            let watchlistDescriptor = FetchDescriptor<SwipedItem>(
                predicate: #Predicate { $0.swipeDirection == "watchlist" }
            )
            watchlistCount = try modelContext.fetchCount(watchlistDescriptor)
        } catch {
            logger.error("Error fetching counts: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Reset Actions
    
    private func resetSkippedItems() {
        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate { $0.swipeDirection == "skipped" }
        )
        
        do {
            let skippedItems = try modelContext.fetch(descriptor)
            for item in skippedItems {
                modelContext.delete(item)
            }
            try modelContext.save()
            refreshCounts()
        } catch {
            logger.error("Error resetting skipped items: \(error.localizedDescription)")
        }
    }
    
    private func resetAllSwipedItems() {
        do {
            try modelContext.delete(model: SwipedItem.self)
            try modelContext.save()
            refreshCounts()
        } catch {
            logger.error("Error resetting all swiped items: \(error.localizedDescription)")
        }
    }
    
    private func resetWatchlistItems() {
        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate { $0.swipeDirection == "watchlist" }
        )
        
        do {
            let watchlistItems = try modelContext.fetch(descriptor)
            for item in watchlistItems {
                modelContext.delete(item)
            }
            try modelContext.save()
            refreshCounts()
        } catch {
            logger.error("Error resetting watchlist items: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [SwipedItem.self], inMemory: true)
}
