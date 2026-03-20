import SwiftUI
import SwiftData
import FirebaseAuth

/// Wrapper to make a String doc ID `Identifiable` for `.sheet(item:)` binding.
private struct SharedListID: Identifiable {
    let docID: String
    var id: String { docID }
}

/// Main content view with tab navigation
struct ContentView: View {
    private let mediaService: any MediaServiceProtocol
    @Environment(AuthService.self) private var authService
    @Environment(CloudSyncService.self) private var cloudSync
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var showDatabaseResetAlert = false
    @State private var sharedListDocID: String?
    /// Tracks the last known UID to detect account switches vs simple sign-in/out.
    @State private var previousUID: String?

    init(mediaService: any MediaServiceProtocol = TMDBService()) {
        self.mediaService = mediaService
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Discover Tab
            SwipeView(mediaService: mediaService)
                .tabItem {
                    Label("Discover", systemImage: "rectangle.stack.fill")
                }
                .tag(0)

            // Search Tab
            SearchView(mediaService: mediaService)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)

            // Library Tab
            FlickSwiperHomeView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(2)

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.primary)
        .onOpenURL { url in
            // 1. Let Google Sign-In handle its OAuth callback URLs first
            if authService.handleGoogleSignInURL(url) {
                return
            }
            // 2. Otherwise, check for deep links (shared lists, etc.)
            if let destination = DeepLinkHandler.destination(from: url) {
                switch destination {
                case .sharedList(let docID):
                    sharedListDocID = docID
                }
            }
        }
        .sheet(item: Binding(
            get: { sharedListDocID.map { SharedListID(docID: $0) } },
            set: { sharedListDocID = $0?.docID }
        )) { item in
            SharedListView(docID: item.docID)
        }
        .onAppear {
            // One-time check: if the database had to be reset on launch, tell the user.
            if FlickSwiperApp.databaseWasReset {
                showDatabaseResetAlert = true
                FlickSwiperApp.databaseWasReset = false // consume the flag
            }
            // Seed previousUID from current auth state so the first onChange
            // doesn't falsely detect a "sign-in" that already happened.
            previousUID = authService.currentUser?.uid
        }
        // MARK: - Cloud Sync: Auth State → Sync Triggers
        .onChange(of: authService.currentUser?.uid) { oldUID, newUID in
            handleAuthChange(oldUID: oldUID, newUID: newUID)
        }
        // Periodic background sync every 5 minutes while app is active
        .task {
            // Initial sync on launch if already signed in
            if authService.currentUser != nil {
                await cloudSync.syncIfNeeded(context: modelContext)
            }
            // Then periodic sync
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { break }
                if authService.currentUser != nil {
                    await cloudSync.syncIfNeeded(context: modelContext)
                }
            }
        }
        .alert("Data Reset Required", isPresented: $showDatabaseResetAlert) {
            Button("OK") { }
        } message: {
            if FlickSwiperApp.isUsingInMemoryFallback {
                Text("Your saved data couldn't be loaded and temporary storage is being used. Your library, watchlist, and lists will not be saved. Please restart the app — if this persists, try reinstalling.")
            } else {
                Text("Your saved data couldn't be loaded and had to be cleared. Your library, watchlist, and lists have been reset. We're sorry for the inconvenience.")
            }
        }
    }
    
    // MARK: - Cloud Sync Helpers
    
    private func handleAuthChange(oldUID: String?, newUID: String?) {
        if let newUID, oldUID == nil {
            // Sign-in: nil → UID
            // Check if local data belongs to a different account (sign-out → sign-in
            // with different provider). If so, treat as account switch to avoid
            // showing stale data from the previous account.
            Task {
                let hasForeignData: Bool
                do {
                    let allItems = try modelContext.fetch(FetchDescriptor<SwipedItem>())
                    hasForeignData = allItems.contains { $0.ownerUID != nil && $0.ownerUID != newUID }
                } catch {
                    hasForeignData = false
                }
                
                if hasForeignData {
                    // Previous account's data is still local — clear it and pull new account
                    do {
                        try await cloudSync.handleAccountSwitch(newUID: newUID, context: modelContext)
                    } catch {
                        // handleAccountSwitch logs internally
                    }
                } else {
                    // True first sign-in or same account re-sign-in — claim unowned + sync
                    do {
                        try cloudSync.claimUnownedRecords(uid: newUID, context: modelContext)
                    } catch {
                        // Non-fatal — records will get claimed on next sync
                    }
                    // If local library is empty but we have a stale sync timestamp
                    // (e.g. re-sign-in after account deletion), force a full pull
                    // so incremental sync doesn't skip all existing Firestore data.
                    // Only clear sync timestamp if we're certain the library is empty.
                    // Use -1 as error sentinel so a SwiftData error doesn't trigger a full pull.
                    let localCount = (try? modelContext.fetchCount(FetchDescriptor<SwipedItem>())) ?? -1
                    if localCount == 0 {
                        cloudSync.clearSyncTimestamp()
                    }
                    await cloudSync.syncIfNeeded(context: modelContext)
                }
            }
            previousUID = newUID
        } else if newUID == nil, oldUID != nil {
            // Sign-out: UID → nil
            previousUID = nil
        } else if let newUID, let oldUID, newUID != oldUID {
            // Account switch: UID_A → UID_B
            Task {
                do {
                    try await cloudSync.handleAccountSwitch(newUID: newUID, context: modelContext)
                } catch {
                    // handleAccountSwitch logs internally
                }
            }
            previousUID = newUID
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(AuthService())
        .environment(FollowedListSyncService())
        .environment(CloudSyncService())
        .modelContainer(for: [SwipedItem.self, UserList.self, ListEntry.self, FollowedList.self, FollowedListItem.self], inMemory: true)
}
