# Architecture

This document covers the key architectural decisions in FlickSwiper and the reasoning behind them.

## High-Level Architecture

FlickSwiper follows the **MVVM** (Model-View-ViewModel) pattern with SwiftUI's `@Observable` macro:

```
┌─────────────┐     ┌──────────────────┐     ┌───────────────┐
│   Views      │────▶│  ViewModels       │────▶│  Services      │
│  (SwiftUI)   │◀────│  (@Observable)    │◀────│  (actor)       │
└─────────────┘     └──────────────────┘     └───────────────┘
                           │                         │
                           ▼                         ▼
                    ┌──────────────┐          ┌──────────────┐
                    │  SwiftData    │          │  TMDB API     │
                    │  (on-device)  │          │  (remote)     │
                    └──────────────┘          └──────────────┘
```

- **Views** own no business logic. They bind to ViewModel state and call ViewModel methods on user interaction.
- **ViewModels** (`SwipeViewModel`, `SearchViewModel`) manage state, coordinate between the service layer and SwiftData, and run on `@MainActor`.
- **Services** (`TMDBService`) are `actor`-isolated to ensure thread-safe network access.

## Data Flow: Card Swipe

Here's how a single swipe flows through the system:

```
User swipes right on card
        │
        ▼
MovieCardView detects drag gesture exceeds threshold (100pt)
        │
        ▼
SwipeView triggers fly-off animation (0.2s)
        │
        ▼
SwipeViewModel.handleSwipe(direction: .seen, item:)
        │
        ├──▶ Creates SwipedItem with metadata (genre IDs, platform)
        ├──▶ Inserts into SwiftData ModelContext
        ├──▶ Adds to swipedIDs set (prevents rediscovery)
        ├──▶ Removes card from mediaItems array (next frame via DispatchQueue.main.async)
        └──▶ Triggers prefetchIfNeeded() if queue is running low
                │
                ▼
        InlineRatingPrompt appears (scale+opacity transition)
        User rates 1-5 stars → SwipedItem.personalRating updated
```

The 0.2s delay between the swipe gesture and the callback is critical — it lets the card visually fly off screen before the array mutation removes it, preventing a jarring visual jump.

## Key Design Decisions

### Actor-Based Networking

`TMDBService` is declared as an `actor` rather than a class. This guarantees serial access to mutable state (like retry counters) without manual locking. All callers use `await`, and Swift's concurrency system handles the rest.

### UUID-Based Join Models (No SwiftData Relationships)

Custom lists use a manual join pattern: `UserList` ↔ `ListEntry` ↔ `SwipedItem`, linked by UUID strings rather than SwiftData `@Relationship` declarations. This was a deliberate choice because:

1. SwiftData relationship management in iOS 17.x had known issues with cascading deletes and inverse relationship syncing.
2. UUID-based joins are simpler to debug and migrate.
3. Query predicates work more predictably with string-based lookups.

### Lightweight Schema Migration (V1 → V2)

All new fields in V2 (`personalRating`, `genreIDsString`, `sourcePlatform`) are `Optional`. This allows SwiftData's built-in lightweight migration to add the columns without custom mapping logic. The `SwipeDirection.watchlist` case required no schema change because direction is stored as a `String`.

### Image Caching Strategy

Rather than a third-party image caching library (Kingfisher, SDWebImage), the app uses an enlarged `URLCache.shared` (50MB memory / 200MB disk) set in the app's `init()`. This keeps dependencies at zero while still providing HTTP-level caching. The `RetryAsyncImage` wrapper handles transient network failures with up to 2 retries.

### Content Type as String Enum

`SwipedItem.direction` is stored as a raw `String` ("seen", "skipped", "watchlist") rather than an integer. This makes the persisted data human-readable when debugging and avoids fragile integer mappings when adding new cases.

## Concurrency Model

| Component | Isolation | Why |
|-----------|-----------|-----|
| `TMDBService` | `actor` | Thread-safe API calls, rate limit retry state |
| `SwipeViewModel` | `@MainActor` (implicit via `@Observable`) | UI state must update on main thread |
| `SearchViewModel` | `@MainActor` | Same — drives UI bindings |
| Search debounce | `Task` cancellation | Cancels in-flight search when user types new characters (400ms debounce) |
| Image prefetch | `Task.detached` | Background downloads don't block UI |

## Query Predicate Strategy

SwiftData queries are scoped carefully to avoid mixing seen and watchlist items:

- **Seen-only**: Smart collections, seen grids, search "already seen" checks — filter on `direction == "seen"`
- **Watchlist-only**: Watchlist section, watchlist grid, watchlist count in settings — filter on `direction == "watchlist"`
- **Library-wide**: Custom list membership, bulk add views — include both seen and watchlist
- **All directions**: `SwipeViewModel.swipedIDs` — includes seen, skipped, and watchlist to prevent any swiped item from reappearing in discovery

## Testing

The codebase includes `MediaServiceProtocol` with a `MockMediaService` actor for dependency injection. ViewModels accept the protocol, making it possible to test discovery and search logic with controlled data. The mock supports configurable responses, error simulation, and call tracking.

## Security: API Key Storage

### How it works

The TMDB API Read Access Token is stored in `Config/Secrets.xcconfig`, which is gitignored. The xcconfig value is referenced in `Info.plist` via the `$(TMDB_API_TOKEN)` variable, and read at runtime with `Bundle.main.object(forInfoDictionaryKey:)`.

### Known trade-off

`Info.plist` is an unencrypted plaintext file inside the `.app` bundle. Anyone who downloads the IPA can extract it and read the token. **This is accepted** for the following reasons:

1. **Read-only token.** TMDB v4 Read Access Tokens only allow fetching public data (movie details, search, trending). They cannot modify anything on TMDB.
2. **Rate-limited.** TMDB enforces per-token rate limits (~40 req/10s). Abuse gets the token throttled, not the account compromised.
3. **Revocable.** If the token is abused, it can be rotated in seconds at themoviedb.org/settings/api and shipped in the next build.
4. **No user data exposure.** The token grants no access to user-specific data — FlickSwiper has no TMDB user accounts.
5. **Zero-dependency goal.** Alternatives (obfuscation libs, backend proxy, CloudKit key storage) add complexity disproportionate to the risk for a read-only public API key.

### What this is NOT acceptable for

This pattern must **not** be reused for tokens that can write data, access user accounts, cost money (payment APIs), or expose PII. Those require Keychain storage at minimum, ideally a server-side proxy so the key never ships in the client binary.

### Mitigation steps taken

- `Secrets.xcconfig` is in `.gitignore` — the real token never enters version control.
- `Secrets.xcconfig.template` documents setup without exposing the real value.
- `resolveAPIToken()` validates the token at runtime and throws `TMDBError.noAPIKey` if it's missing, preventing silent failures.
- The token should be rotated before each public release if the repo is public.
