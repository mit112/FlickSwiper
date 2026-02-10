import SwiftUI
import SwiftData

@main
struct WatchVaultApp: App {
    
    init() {
        // Configure URL cache for poster images
        // 50MB memory cache + 200MB disk cache
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,   // 50 MB
            diskCapacity: 200 * 1024 * 1024,      // 200 MB
            directory: nil  // uses default cache directory
        )
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([SwipedItem.self, UserList.self, ListEntry.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: WatchVaultMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            #if DEBUG
            // If the existing store was created before VersionedSchema (unknown model version),
            // remove it so we can create a fresh store. Development only — user loses local data.
            if let swiftDataError = error as? SwiftDataError,
               String(describing: swiftDataError).contains("loadIssueModelContainer") {
                if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                    let storeURL = appSupport.appendingPathComponent("default.store")
                    try? FileManager.default.removeItem(at: storeURL)
                    try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
                    try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
                    if let container = try? ModelContainer(for: schema, configurations: [modelConfiguration]) {
                        return container
                    }
                }
            }
            #endif
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
