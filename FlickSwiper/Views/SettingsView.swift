import SwiftUI
import SwiftData
import os

/// Full settings screen with discovery controls, about info, and support links
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(FollowedListSyncService.self) private var syncService
    @Environment(CloudSyncService.self) private var cloudSync
    private let logger = Logger(subsystem: "com.flickswiper.app", category: "SettingsView")
    
    @AppStorage(Constants.StorageKeys.includeSwipedItems) private var includeSwipedItems: Bool = false
    @AppStorage(Constants.StorageKeys.hasSeenSwipeTutorial) private var hasSeenTutorial = false
    @AppStorage(Constants.StorageKeys.ratingDisplayOption) private var ratingDisplayRaw: String = RatingDisplayOption.tmdb.rawValue
    @State private var showResetConfirmation = false
    @State private var resetType: ResetType = .skipped
    @State private var showResetWatchlistConfirmation = false
    @State private var resetErrorMessage: String?
    
    // Account state
    @State private var showSignInPrompt = false
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showEditDisplayName = false
    @State private var editedDisplayName = ""
    @State private var accountErrorMessage: String?
    
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
                // Force standard gray section headers (not accent-tinted)
                // MARK: - Account Section
                Section {
                    if authService.isSignedIn {
                        HStack {
                            Text("Signed in as")
                            Spacer()
                            Text(authService.displayName)
                                .foregroundStyle(.secondary)
                        }
                        
                        Button {
                            editedDisplayName = authService.displayName
                            showEditDisplayName = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                    .foregroundStyle(Color.accentColor)
                                Text("Edit Display Name")
                                    .foregroundStyle(.primary)
                            }
                        }
                        
                        Button {
                            showSignOutConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundStyle(.orange)
                                Text("Sign Out")
                                    .foregroundStyle(.primary)
                            }
                        }
                        
                        Button(role: .destructive) {
                            showDeleteAccountConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.xmark")
                                    .foregroundStyle(.red)
                                Text("Delete Account")
                                    .foregroundStyle(.primary)
                            }
                        }
                    } else {
                        Button {
                            showSignInPrompt = true
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .foregroundStyle(Color.accentColor)
                                Text("Sign In")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("For list sharing")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Account")
                        .foregroundStyle(Color(.secondaryLabel))
                } footer: {
                    if authService.isSignedIn {
                        Text("Your account is used for sharing lists and backing up your library to the cloud.")
                    } else {
                        Text("Sign in with Apple or Google to back up your library and share lists with friends. Optional \u{2014} all other features work without an account.")
                    }
                }
                
                // MARK: - Cloud Sync Section
                if authService.isSignedIn {
                    Section {
                        HStack {
                            Text("Sync Status")
                            Spacer()
                            switch cloudSync.syncState {
                            case .idle:
                                Text("Idle")
                                    .foregroundStyle(.secondary)
                            case .syncing:
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Syncing\u{2026}")
                                        .foregroundStyle(.secondary)
                                }
                            case .synced(let date):
                                Text("Synced \(date.formatted(.relative(presentation: .named)))")
                                    .foregroundStyle(.secondary)
                            case .failed(let message):
                                Text("Failed")
                                    .foregroundStyle(.red)
                                    .help(message)
                            }
                        }
                        
                        Button {
                            Task {
                                cloudSync.clearSyncTimestamp()
                                await cloudSync.syncIfNeeded(context: modelContext)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(Color.accentColor)
                                Text("Sync Now")
                                    .foregroundStyle(.primary)
                            }
                        }
                        .disabled({
                            if case .syncing = cloudSync.syncState { return true }
                            return false
                        }())
                    } header: {
                        Text("Cloud Backup")
                            .foregroundStyle(Color(.secondaryLabel))
                    } footer: {
                        Text("Your library is automatically backed up when signed in. Changes sync every 5 minutes and on each app launch.")
                    }
                }
                
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
                        .foregroundStyle(Color(.secondaryLabel))
                }
                
                // MARK: - Display Section
                Section {
                    Picker(selection: $ratingDisplayRaw) {
                        ForEach(RatingDisplayOption.allCases) { option in
                            Text(option.rawValue).tag(option.rawValue)
                        }
                    } label: {
                        Text("Rating on Cards")
                    }
                } header: {
                    Text("Display")
                        .foregroundStyle(Color(.secondaryLabel))
                } footer: {
                    Text("Choose which rating appears under posters in your library.")
                }
                
                Section {
                    Toggle("Show Previously Swiped", isOn: $includeSwipedItems)
                } header: {
                    Text("Filters")
                        .foregroundStyle(Color(.secondaryLabel))
                } footer: {
                    Text("Enable this to see titles you've already swiped on. Useful for re-evaluating your choices.")
                }
                
                Section {
                    Button {
                        hasSeenTutorial = false
                    } label: {
                        HStack {
                            Image(systemName: "hand.draw.fill")
                                .foregroundStyle(Color.accentColor)
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
                        .foregroundStyle(Color(.secondaryLabel))
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
                        .foregroundStyle(Color(.secondaryLabel))
                }
                
                // MARK: - Support Section
                Section {
                    Link(destination: Constants.URLs.privacyPolicy) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(Color.accentColor)
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
                                .foregroundStyle(Color.accentColor)
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
                        .foregroundStyle(Color(.secondaryLabel))
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
            .alert(
                "Couldn't Reset Data",
                isPresented: Binding(
                    get: { resetErrorMessage != nil },
                    set: { if !$0 { resetErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { resetErrorMessage = nil }
            } message: {
                Text(resetErrorMessage ?? "Please try again.")
            }
            // MARK: - Account Sheets & Alerts
            .sheet(isPresented: $showSignInPrompt) {
                SignInPromptView(reason: "share lists with friends")
            }
            .alert("Edit Display Name", isPresented: $showEditDisplayName) {
                TextField("Display name", text: $editedDisplayName)
                Button("Save") {
                    saveDisplayName()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This name is shown to people who follow your lists.")
            }
            .confirmationDialog(
                "Sign Out?",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    performSignOut()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You can sign back in anytime. Your library stays on your device.")
            }
            .alert("Delete Account?", isPresented: $showDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Account", role: .destructive) {
                    performAccountDeletion()
                }
            } message: {
                Text("This will permanently delete your account, unpublish all your shared lists, and remove your follows. Your local library is not affected. This cannot be undone.")
            }
            .alert(
                "Account Error",
                isPresented: Binding(
                    get: { accountErrorMessage != nil },
                    set: { if !$0 { accountErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { accountErrorMessage = nil }
            } message: {
                Text(accountErrorMessage ?? "Something went wrong.")
            }
            .overlay {
                if isDeletingAccount {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Deleting account...")
                                .padding(20)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                }
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
            let skippedIDs = skippedItems.map(\.uniqueID)
            // Clean up any ListEntries referencing these items (defensive — skipped
            // items normally aren't in lists, but avoids orphans if state drifted)
            let orphanedEntryIDs = try collectEntryIDs(for: Set(skippedIDs))
            try deleteOrphanedEntries(for: Set(skippedIDs))
            for item in skippedItems {
                modelContext.delete(item)
            }
            try modelContext.save()
            // Push deletes to Firestore
            cloudSync.bulkDeleteSwipedItems(uniqueIDs: skippedIDs)
            if !orphanedEntryIDs.isEmpty {
                cloudSync.bulkDeleteListEntries(entryIDs: orphanedEntryIDs)
            }
            refreshCounts()
        } catch {
            logger.error("Error resetting skipped items: \(error.localizedDescription)")
            resetErrorMessage = "We couldn't reset skipped items. Please try again."
        }
    }
    
    private func resetAllSwipedItems() {
        do {
            // Gather IDs before deleting so we can push to Firestore
            let allEntries = try modelContext.fetch(FetchDescriptor<ListEntry>())
            let entryIDs = allEntries.map(\.id)
            for entry in allEntries {
                modelContext.delete(entry)
            }
            let allSwipedItems = try modelContext.fetch(FetchDescriptor<SwipedItem>())
            let itemIDs = allSwipedItems.map(\.uniqueID)
            for item in allSwipedItems {
                modelContext.delete(item)
            }
            try modelContext.save()
            // Push deletes to Firestore
            cloudSync.bulkDeleteSwipedItems(uniqueIDs: itemIDs)
            cloudSync.bulkDeleteListEntries(entryIDs: entryIDs)
            refreshCounts()
        } catch {
            logger.error("Error resetting all swiped items: \(error.localizedDescription)")
            resetErrorMessage = "We couldn't reset all swiped items. Please try again."
        }
    }
    
    private func resetWatchlistItems() {
        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate { $0.swipeDirection == "watchlist" }
        )
        
        do {
            let watchlistItems = try modelContext.fetch(descriptor)
            let watchlistUniqueIDs = watchlistItems.map(\.uniqueID)
            // Clean up ListEntries that reference these watchlist items
            let orphanedEntryIDs = try collectEntryIDs(for: Set(watchlistUniqueIDs))
            try deleteOrphanedEntries(for: Set(watchlistUniqueIDs))
            for item in watchlistItems {
                modelContext.delete(item)
            }
            try modelContext.save()
            // Push deletes to Firestore
            cloudSync.bulkDeleteSwipedItems(uniqueIDs: watchlistUniqueIDs)
            if !orphanedEntryIDs.isEmpty {
                cloudSync.bulkDeleteListEntries(entryIDs: orphanedEntryIDs)
            }
            refreshCounts()
        } catch {
            logger.error("Error resetting watchlist items: \(error.localizedDescription)")
            resetErrorMessage = "We couldn't clear watchlist items. Please try again."
        }
    }
    
    /// Collect entry UUIDs for items about to be deleted (before removing them).
    /// Used to push bulk deletes to Firestore.
    private func collectEntryIDs(for itemIDs: Set<String>) throws -> [UUID] {
        var entryIDs: [UUID] = []
        for itemID in itemIDs {
            let id = itemID
            let descriptor = FetchDescriptor<ListEntry>(
                predicate: #Predicate<ListEntry> { $0.itemID == id }
            )
            let entries = try modelContext.fetch(descriptor)
            entryIDs.append(contentsOf: entries.map(\.id))
        }
        return entryIDs
    }
    
    /// Delete all ListEntry records whose itemID is in the given set.
    private func deleteOrphanedEntries(for itemIDs: Set<String>) throws {
        for itemID in itemIDs {
            let id = itemID
            let descriptor = FetchDescriptor<ListEntry>(
                predicate: #Predicate<ListEntry> { $0.itemID == id }
            )
            let entries = try modelContext.fetch(descriptor)
            for entry in entries {
                modelContext.delete(entry)
            }
        }
    }
    
    // MARK: - Account Actions
    
    private func saveDisplayName() {
        let newName = editedDisplayName
        Task {
            do {
                try await authService.updateDisplayName(newName)
            } catch {
                logger.error("Display name update failed: \(error.localizedDescription)")
                accountErrorMessage = error.localizedDescription
            }
        }
    }
    
    private func performSignOut() {
        // Push any pending local changes to Firestore before signing out
        Task {
            await cloudSync.syncIfNeeded(context: modelContext)
            do {
                syncService.deactivate()
                try authService.signOut()
            } catch {
                logger.error("Sign out failed: \(error.localizedDescription)")
                accountErrorMessage = "Couldn't sign out. Please try again."
            }
        }
    }
    
    private func performAccountDeletion() {
        isDeletingAccount = true
        Task {
            do {
                // Deactivate sync listeners
                syncService.deactivate()
                
                // Push any final local changes before account removal
                await cloudSync.syncIfNeeded(context: modelContext)
                
                // Clean up local followed list data
                let followedLists = try modelContext.fetch(FetchDescriptor<FollowedList>())
                let followedItems = try modelContext.fetch(FetchDescriptor<FollowedListItem>())
                for item in followedItems {
                    modelContext.delete(item)
                }
                for list in followedLists {
                    modelContext.delete(list)
                }
                
                // Clear publish state on local lists (they stay as local lists)
                let userLists = try modelContext.fetch(FetchDescriptor<UserList>())
                for list in userLists {
                    list.firestoreDocID = nil
                    list.isPublished = false
                    list.lastSyncedAt = nil
                }
                try modelContext.save()
                
                // Clear the per-user sync timestamp so a full pull happens if
                // they sign back in with the same account later.
                cloudSync.clearSyncTimestamp()
                
                // Delete account from Firebase (Firestore cleanup + auth deletion).
                // If session is stale, this will re-auth automatically then retry.
                try await authService.deleteAccount()
                
                isDeletingAccount = false
            } catch {
                isDeletingAccount = false
                logger.error("Account deletion failed: \(error.localizedDescription)")
                // Delay so the confirmation dialog finishes dismissing before showing error alert.
                try? await Task.sleep(for: .milliseconds(500))
                accountErrorMessage = "Couldn't delete your account: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AuthService())
        .environment(FollowedListSyncService())
        .environment(CloudSyncService())
        .modelContainer(for: [SwipedItem.self, UserList.self, ListEntry.self, FollowedList.self, FollowedListItem.self], inMemory: true)
}
