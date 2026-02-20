# Changelog

All notable changes to FlickSwiper, in reverse chronological order.

---

## v1.3 — Social Lists & Schema Migration Fix (February 2026)

Social sharing feature and a critical fix for SwiftData schema migration that was silently wiping user data on upgrades.

### Critical Fix: Schema Migration

- **Frozen versioned schema definitions** — `VersionedSchema` enums (V1, V2) were referencing the current top-level model types, which included properties added in later versions. SwiftData hashes the model graph to identify the on-disk store version, so V1's schema hash included V2/V3 fields that didn't exist when the store was created. This produced "Cannot use staged migration with an unknown model version" (NSCocoaErrorDomain 134504), triggering the tier-2 recovery path that deletes all user data. Fixed by defining frozen model copies nested inside each `VersionedSchema` enum. V3 (current) still references the live top-level types. Entity names preserved via Swift enum namespacing (`FlickSwiperSchemaV1.SwipedItem` maps to entity "SwipedItem"). (`SchemaVersions.swift`)

### Social Lists

- **Sign in with Apple** — Firebase Auth integration with `ASAuthorizationController`. Display name collected on first sign-in via a validation sheet (`DisplayNameValidator`). Auth state observed via `AuthService` injected as an `@Observable` environment value. (`AuthService.swift`, `ContentView.swift`)

- **List publishing** — Users can publish any custom list to Firestore. `ListPublisher` handles create/update/unpublish/delete lifecycle with embedded item arrays for read performance. `UserList` gained `firestoreDocID`, `isPublished`, and `lastSyncedAt` fields (V3 schema, all optional). (`ListPublisher.swift`, `UserList.swift`)

- **Following lists** — Users can follow published lists via Universal Links (`flickswiper.app/list/{docID}`). `DeepLinkHandler` parses inbound URLs and coordinates navigation. `FollowedList` and `FollowedListItem` models cache remote data locally. (`DeepLinkHandler.swift`, `FollowedList.swift`, `FollowedListItem.swift`)

- **Real-time sync** — `FollowedListSyncService` attaches Firestore snapshot listeners for followed lists, updating local SwiftData cache on remote changes. Activated lazily when signed in. (`FollowedListSyncService.swift`)

- **Share sheet** — `ShareLinkSheet` generates Universal Links for published lists with `UIActivityViewController`. (`ShareLinkSheet.swift`)

- **Firestore service** — `FirestoreService` handles all Firestore read/write operations with proper error handling and Sendable compliance. (`FirestoreService.swift`)

- **Library UI updates** — `FollowingSection` in Library tab shows followed lists. `MyListsSection` shows publish status badges. List detail views include publish/unpublish/share actions for authenticated users. (`FollowingSection.swift`, `MyListsSection.swift`, `FlickSwiperHomeView.swift`)

- **Schema V2→V3 migration** — Lightweight migration adding three optional fields to `UserList` and two new models (`FollowedList`, `FollowedListItem`). (`SchemaVersions.swift`)

### Tests

- **DeepLinkHandler tests** — Covers valid/invalid URL parsing, path extraction, and edge cases. (`DeepLinkHandlerTests.swift`)
- **DisplayNameValidator tests** — Covers length limits, character restrictions, trimming, and boundary cases. (`DisplayNameValidatorTests.swift`)

---

## v1.1 — Production Hardening (February 2026)

Focused pass on crash safety, concurrency correctness, testability, and App Store readiness.

### Crash Safety

- **Three-tier database recovery** — Replaced `fatalError` in `ModelContainer` initialization with a graceful fallback chain: normal init → delete corrupted store and retry → in-memory fallback. The app now always launches, even with a corrupted database. `ContentView` shows a one-time alert if data had to be cleared. (`FlickSwiperApp.swift`, `ContentView.swift`)

- **Safe API token resolution** — Replaced `fatalError` in API token validation with a throwing `resolveAPIToken()` method. Missing or placeholder tokens now propagate as `TMDBError.noAPIKey` through the normal error flow, showing a user-friendly message instead of crashing. Also fixed a `URLComponents` force-unwrap in the network request method. (`TMDBService.swift`)

- **Bounded auto-pagination** — `loadContent()` previously used unbounded recursive `Task` calls when most fetched items were already swiped. Replaced with a `while` loop capped at 5 consecutive pages to prevent runaway API calls. (`SwipeViewModel.swift`)

### Concurrency

- **Explicit `@MainActor` on ViewModels** — Added `@MainActor` to both `SwipeViewModel` and `SearchViewModel`. All properties drive `@Observable` UI bindings and must be accessed on the main thread. Removed verbose `await MainActor.run { }` wrappers that were papering over the missing isolation. (`SwipeViewModel.swift`, `SearchViewModel.swift`)

- **Structured concurrency for animation timing** — Replaced 12 instances of `DispatchQueue.main.asyncAfter` across 7 files with `Task { try? await Task.sleep(...) }`. These now participate in structured concurrency and are automatically cancelled when views disappear. (`SwipeView.swift`, `MovieCardView.swift`, `SearchView.swift`, `FlickSwiperHomeView.swift`, `WatchlistGridView.swift`, `InlineRatingPrompt.swift`, `RetryAsyncImage.swift`)

### Testing

- **Unit test suite** — Added 7 test files with ~80+ tests covering JSON decoding, model conversions, computed properties, ViewModel swipe/undo/search logic, error propagation, debounce cancellation, enum completeness, direction protection (demotion prevention for seen/watchlist items), undo with pre-existing records, cross-type ID uniqueness (movie vs TV with same TMDB ID), rating preservation through re-encounters, and ListEntry orphan scenarios. Uses in-memory `ModelContainer` for SwiftData tests. (`FlickSwiperTests/`)

- **Dependency injection for SearchViewModel** — Applied the same DI pattern from `SwipeViewModel`: injectable `MediaServiceProtocol` with default `TMDBService()`. Enables testing without network calls. (`SearchViewModel.swift`)

- **MockMediaService in test target** — Moved mock service from production code to `FlickSwiperTests/` so it doesn't ship in the release binary. Consolidated actor-safe helper extensions in one file. (`MockMediaService.swift`)

### Architecture Cleanup

- **Smart collection query optimization** — `SmartCollectionsSection` now owns its own `@Query` instead of receiving the full seen-items array from the parent. Caches computed collections in `@State` and only rebuilds when the item count changes, avoiding expensive multi-pass iteration on every parent re-render. (`SmartCollectionsSection.swift`, `FlickSwiperHomeView.swift`)

- **Direction string constants** — Extracted `"seen"`, `"skipped"`, `"watchlist"` magic strings into static constants on `SwipedItem`. `#Predicate` macros still require string literals (SwiftData limitation), but all non-predicate comparisons now use the constants. (`SwipedItem.swift`)

- **Model type extraction** — Moved `SeenFilter` and `SmartCollection` from `SmartCollectionCard.swift` (a view file) to `Models/SmartCollection.swift` for proper separation of concerns. (`SmartCollection.swift`)

- **Centralized URLs** — Moved force-unwrapped URL literals from `SettingsView` into `Constants.URLs`. (`Constants.swift`, `SettingsView.swift`)

### Data Integrity — Deduplication Audit

Comprehensive audit of how titles are uniquely identified, stored, filtered, and rendered across the app. Two shakedown rounds uncovered and fixed critical data-loss paths.

- **SearchView ID collision fix** — Search tab status indicators (`seenMediaIDs`, `watchlistMediaIDs`) used bare `Set<Int>` of TMDB IDs, which collided between movies and TV shows sharing the same numeric ID. Replaced with `Set<String>` using the composite `uniqueID` key (`"mediaType_tmdbID"`). A movie and TV show with the same TMDB ID are now correctly treated as distinct items everywhere. (`SearchView.swift`)

- **Existence check before insert** — `SwipedItemStore.markAsSeen` and `saveToWatchlist` now call `findExisting(uniqueID:)` before inserting. If a record already exists, it updates direction and dateSwiped in-place, preserving `personalRating`, `genreIDsString`, and all other user data. Prevents SwiftData's `@Attribute(.unique)` upsert from silently resetting fields. Same pattern applied to `SwipeViewModel.swipeRight`, `swipeLeft`, and new `swipeUp`. (`SwipedItemStore.swift`, `SwipeViewModel.swift`)

- **Direction transition policy** — Direction hierarchy: seen (2) > watchlist (1) > skipped (0). Promotions always allowed; demotions silently ignored. A "seen" item cannot be demoted to "watchlist" or "skipped" by re-encountering it in Discover with "Show Previously Swiped" enabled. Policy enforced in both `SwipedItemStore` (Search tab path) and `SwipeViewModel` (Discover tab path). (`SwipedItemStore.swift`, `SwipeViewModel.swift`)

- **Undo redesign** — Undo stack entries now carry `previousDirection: String?`. For newly created records (`nil`), undo deletes the record. For pre-existing records, undo restores the original direction without deleting. Prevents undo from permanently destroying a library item that was merely skipped in Discover. Introduced `UndoEntry` struct replacing the old tuple. (`SwipeViewModel.swift`)

- **New `swipeUp` method** — Unified watchlist-from-Discover flow into `SwipeViewModel.swipeUp(item:context:)` with full direction protection and undo support. Replaces the manual 3-step dance (add to undo stack, call SwipedItemStore directly, remove card from stack) in `SwipeView.saveToWatchlist`. (`SwipeViewModel.swift`, `SwipeView.swift`)

- **ListEntry orphan cleanup** — All SwipedItem deletion paths now clean up associated `ListEntry` records: `SwipedItemStore.remove()`, `SettingsView.resetAllSwipedItems`, `resetSkippedItems`, `resetWatchlistItems`. Prevents ghost entries from inflating custom list counts after resets. (`SwipedItemStore.swift`, `SettingsView.swift`)

- **Discovery feed deduplication** — `loadContent()` deduplicates fetched items against the existing `mediaItems` queue before appending. Prevents duplicate cards from TMDB pagination instability. Added `consecutiveZeroYield` counter (narrowed to true pagination overlap only) for early exit on fully-duplicate pages. (`SwipeViewModel.swift`)

- **Library search includes watchlist** — Library tab search now filters across both seen and watchlist items, sorted by recency. Watchlist results show a blue bookmark badge and tap through to `WatchlistItemDetailView`. (`FlickSwiperHomeView.swift`)

- **Smart collection rebuild on data changes** — `SmartCollectionsSection` now rebuilds when `personalRating` or `sourcePlatform` changes (not just item count), via a computed hash of relevant fields. (`SmartCollectionsSection.swift`)

- **BulkAddToListView guard** — `applyChanges()` re-checks live entries before inserting to guard against duplicate `ListEntry` records when the sheet's captured snapshot is stale. (`BulkAddToListView.swift`)

- **Rating prompt skip for rated items** — Discover tab's inline rating prompt is suppressed when the returned `SwipedItem` already has a `personalRating` (re-encounter scenario). Prevents accidental rating overwrites. (`SwipeView.swift`)

- **Dead code removal** — Removed `resetAllSwipedItems(context:)` and `resetSkippedItems(context:)` from `SwipeViewModel` (40 lines). These duplicated SettingsView's private implementations and were never called. (`SwipeViewModel.swift`)

- **Preview container fixes** — `SwipeView` and `SettingsView` `#Preview` containers updated to include all three models (`SwipedItem`, `UserList`, `ListEntry`) to match runtime requirements.

### Accessibility & UX

- **Watchlist accessibility action** — Added VoiceOver action for "Save to watchlist" on swipe cards. All three swipe directions now have accessibility equivalents. (`MovieCardView.swift`)

- **Offline state detection** — Added dedicated offline UI (wifi.slash icon, "You're Offline" heading, reassurance that Library still works) instead of showing a generic error triangle when the device has no connectivity. Uses a `NetworkError` utility that checks for `URLError` offline codes. (`NetworkError.swift`, `SwipeViewModel.swift`, `SearchViewModel.swift`, `SwipeView.swift`, `SearchView.swift`)

---

## v1.0 — Initial Release (February 2026)

Core app with all features:

- **Discover tab** — Tinder-style swipe cards for movies and TV shows. Swipe right (seen), left (skip), up (watchlist). Browse by trending, popular, top rated, now playing, upcoming, and 11 streaming services. Filter by genre, year range, and content type. Sort streaming catalogs.

- **Rating system** — 1–5 star inline rating prompt after marking content as seen. Smooth scale+opacity transition over dimmed card stack.

- **Search tab** — Debounced TMDB search (400ms) with library-aware status indicators. Green checkmarks for seen items, blue bookmarks for watchlist.

- **Library tab** — Smart collections (favorites, genres, platforms, recently added), custom lists with bulk add, Apple-style edit mode with multi-select and bottom action bar, watchlist section with "I've Watched This" conversion flow.

- **Data layer** — SwiftData with versioned schema migration (V1→V2), UUID-based join models for custom lists, actor-isolated TMDB networking with rate limit handling.

- **Image caching** — Enlarged URLCache (50MB memory / 200MB disk), RetryAsyncImage wrapper, prefetch for both poster and thumbnail sizes.

- **Privacy** — All data stored locally on device. No accounts, no analytics, no tracking. PrivacyInfo.xcprivacy configured.
