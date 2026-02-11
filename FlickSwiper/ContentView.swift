import SwiftUI
import SwiftData

/// Main content view with tab navigation
struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Discover Tab
            SwipeView()
                .tabItem {
                    Label("Discover", systemImage: "rectangle.stack.fill")
                }
                .tag(0)

            // Search Tab
            SearchView()
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SwipedItem.self, UserList.self, ListEntry.self], inMemory: true)
}
