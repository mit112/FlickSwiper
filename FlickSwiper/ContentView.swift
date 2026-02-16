import SwiftUI
import SwiftData

/// Main content view with tab navigation
struct ContentView: View {
    private let mediaService: any MediaServiceProtocol
    @State private var selectedTab = 0
    @State private var showDatabaseResetAlert = false

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
        .onAppear {
            // One-time check: if the database had to be reset on launch, tell the user.
            if FlickSwiperApp.databaseWasReset {
                showDatabaseResetAlert = true
                FlickSwiperApp.databaseWasReset = false // consume the flag
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
}

#Preview {
    ContentView()
        .modelContainer(for: [SwipedItem.self, UserList.self, ListEntry.self], inMemory: true)
}
