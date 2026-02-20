import SwiftUI
import SwiftData
import FirebaseCore
import os

/// Structured logger for app lifecycle and database recovery diagnostics.
/// Uses os.Logger for proper integration with Console.app and device logs.
private let logger = Logger(subsystem: "com.flickswiper.app", category: "Lifecycle")

@main
struct FlickSwiperApp: App {
    private let mediaService: any MediaServiceProtocol = TMDBService()
    
    /// Shared auth service for Sign in with Apple + Firebase Auth.
    /// Injected into the view hierarchy via .environment().
    @State private var authService = AuthService()
    
    /// Real-time sync service for followed lists.
    /// Activated lazily when user is signed in and viewing Library.
    @State private var followedListSyncService = FollowedListSyncService()
    
    // MARK: - Database Recovery State
    
    /// Indicates the persistent store had to be deleted and recreated due to corruption.
    /// ContentView observes this to show a one-time alert informing the user.
    static var databaseWasReset = false
    
    /// True when even store deletion failed and we fell back to an in-memory container.
    /// Data will not persist across launches in this state.
    static var isUsingInMemoryFallback = false
    
    init() {
        // Initialize Firebase — must be called before any Firebase service
        FirebaseApp.configure()
        
        // Now safe to set up auth listener (requires Firebase to be configured first)
        authService.configure()
        
        // Configure URL cache for poster images
        // 50MB memory cache + 200MB disk cache
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,   // 50 MB
            diskCapacity: 200 * 1024 * 1024,      // 200 MB
            directory: nil  // uses default cache directory
        )
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([SwipedItem.self, UserList.self, ListEntry.self,
                             FollowedList.self, FollowedListItem.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        // Attempt 1: Normal initialization with migration plan
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: FlickSwiperMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            logger.error("ModelContainer init failed: \(error.localizedDescription)")
            
            // Attempt 2: Delete corrupted store files and create a fresh container.
            // This loses all user data but lets the app launch instead of crash-looping.
            if let recovered = deleteStoreAndRetry(schema: schema, configuration: modelConfiguration) {
                FlickSwiperApp.databaseWasReset = true
                logger.warning("Recovered by deleting corrupted store.")
                return recovered
            }
            
            // Attempt 3: Last resort — in-memory container so the app at least opens.
            // Nothing persists, but the user can still browse and we avoid a crash loop.
            logger.critical("Store deletion failed. Falling back to in-memory container.")
            FlickSwiperApp.databaseWasReset = true
            FlickSwiperApp.isUsingInMemoryFallback = true
            
            let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } catch {
                // If we can't even create an in-memory container the framework itself is broken.
                // This is the only remaining fatalError — it should be effectively unreachable.
                fatalError("Cannot create any ModelContainer: \(error)")
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView(mediaService: mediaService)
                .environment(authService)
                .environment(followedListSyncService)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Store Recovery

/// Deletes the default SwiftData store files and attempts to create a fresh container.
/// Returns nil if recovery fails.
///
/// SwiftData's default store is at:
///   ~/Library/Application Support/default.store  (+ .shm, .wal journal files)
private func deleteStoreAndRetry(
    schema: Schema,
    configuration: ModelConfiguration
) -> ModelContainer? {
    guard let appSupport = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first else {
        logger.error("Could not locate Application Support directory.")
        return nil
    }
    
    let storeURL = appSupport.appendingPathComponent("default.store")
    
    // Remove the main store file and its SQLite journal companions
    for url in [
        storeURL,
        storeURL.appendingPathExtension("shm"),
        storeURL.appendingPathExtension("wal")
    ] {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            logger.error("Failed to delete \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
    
    // Try creating a fresh container (no migration plan needed for an empty store)
    return try? ModelContainer(for: schema, configurations: [configuration])
}
