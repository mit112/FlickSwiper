# Changelog

All notable changes to FlickSwiper, in reverse chronological order.

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

- **Unit test suite** — Added 7 test files with ~67 tests covering JSON decoding, model conversions, computed properties, ViewModel swipe/undo/search logic, error propagation, debounce cancellation, and enum completeness. Uses in-memory `ModelContainer` for SwiftData tests. (`FlickSwiperTests/`)

- **Dependency injection for SearchViewModel** — Applied the same DI pattern from `SwipeViewModel`: injectable `MediaServiceProtocol` with default `TMDBService()`. Enables testing without network calls. (`SearchViewModel.swift`)

- **MockMediaService in test target** — Moved mock service from production code to `FlickSwiperTests/` so it doesn't ship in the release binary. Consolidated actor-safe helper extensions in one file. (`MockMediaService.swift`)

### Architecture Cleanup

- **Smart collection query optimization** — `SmartCollectionsSection` now owns its own `@Query` instead of receiving the full seen-items array from the parent. Caches computed collections in `@State` and only rebuilds when the item count changes, avoiding expensive multi-pass iteration on every parent re-render. (`SmartCollectionsSection.swift`, `FlickSwiperHomeView.swift`)

- **Direction string constants** — Extracted `"seen"`, `"skipped"`, `"watchlist"` magic strings into static constants on `SwipedItem`. `#Predicate` macros still require string literals (SwiftData limitation), but all non-predicate comparisons now use the constants. (`SwipedItem.swift`)

- **Model type extraction** — Moved `SeenFilter` and `SmartCollection` from `SmartCollectionCard.swift` (a view file) to `Models/SmartCollection.swift` for proper separation of concerns. (`SmartCollection.swift`)

- **Centralized URLs** — Moved force-unwrapped URL literals from `SettingsView` into `Constants.URLs`. (`Constants.swift`, `SettingsView.swift`)

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
