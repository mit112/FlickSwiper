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
                           │
                           ▼
                    ┌──────────────┐
                    │  Firebase     │
                    │  (Auth +      │
                    │   Firestore)  │
                    └──────────────┘
```

- **Views** own no business logic. They bind to ViewModel state and call ViewModel methods on user interaction.
- **ViewModels** (`SwipeViewModel`, `SearchViewModel`) manage state, coordinate between the service layer and SwiftData, and run on `@MainActor`.
- **Services** (`TMDBService`, `CloudSyncService`, `AuthService`, `ListPublisher`, `FollowedListSyncService`) handle networking, authentication, cloud sync, and social features. `TMDBService` is `actor`-isolated; the Firebase services are `@Observable` + `@MainActor`.

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
        ├──▶ Sets lastModified + ownerUID (cloud sync fields)
        ├──▶ Inserts into SwiftData ModelContext
        ├──▶ Pushes to Firestore via CloudSyncService (if signed in)
        ├──▶ Adds to swipedIDs set (prevents rediscovery)
        ├──▶ Removes card from mediaItems array
        └──▶ Triggers prefetchIfNeeded() if queue is running low
                │
                ▼
        InlineRatingPrompt appears (scale+opacity transition)
        User rates 1-5 stars → SwipedItem.personalRating updated + pushed to Firestore
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

### Frozen Versioned Schema Definitions (V1 → V4)

SwiftData hashes the entire model graph to identify on-disk store versions. Early versions referenced the current top-level model types (which included later fields), causing hash mismatches and the "Cannot use staged migration with an unknown model version" error. This triggered the tier-2 recovery path that silently wiped user data.

Fixed by defining frozen model copies nested inside each `VersionedSchema` enum. Each schema version contains exact snapshots of every model as it existed at that version. V4 (current) references the live top-level types. All new fields across versions are `Optional` with defaults, enabling lightweight migration at every step.

### Direction Transition Policy

Direction hierarchy: seen (2) > watchlist (1) > skipped (0). Promotions always allowed; demotions silently ignored. A "seen" item cannot be demoted to "watchlist" or "skipped" by re-encountering it in Discover. Enforced in both `SwipedItemStore` (Search path) and `SwipeViewModel` (Discover path). Undo uses `UndoEntry` with `previousDirection: String?` to restore the correct state without destroying records.

### Cloud Sync: Push-on-Write + Incremental Pull

`CloudSyncService` uses a push-on-write strategy: every local mutation immediately writes through to Firestore. On launch and periodically (every 5 minutes), an incremental pull fetches all records modified since the last sync timestamp. Merge conflicts are resolved by most-recent `lastModified` wins, but direction hierarchy is never violated.

Firestore structure: `users/{uid}/swipedItems/{uniqueID}`, `users/{uid}/userLists/{uuid}`, `users/{uid}/listEntries/{uuid}`. Batch uploads are chunked at 400 operations (under Firestore's 500 limit).

Account switching clears local data and pulls the new account's data. `ownerUID` on every record enables detecting foreign-owned data after provider switches.

### Social Lists: Publish + Follow Architecture

`ListPublisher` serializes `ListEntry` + `SwipedItem` data into a flat Firestore `publishedLists` document with embedded items for read performance. The follow flow creates a Firestore `follows` doc plus local `FollowedList` + `FollowedListItem` SwiftData records.

`FollowedListSyncService` attaches one Firestore `addSnapshotListener` per followed list. On remote changes, it updates local SwiftData cache. When a list owner deactivates a list, followers see a "deactivated" banner and the list freezes.

Universal Links route through GitHub Pages AASA file → `DeepLinkHandler` URL parser → `SharedListView` sheet presentation.

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
| `AuthService` | `@Observable` + `@MainActor` | Auth state drives UI, must be on main thread |
| `CloudSyncService` | `@Observable` + `@MainActor` | Sync state drives UI; SwiftData context access requires main actor |
| `FollowedListSyncService` | `@Observable` + `@MainActor` | Firestore listeners update SwiftData on main thread |
| `FirestoreService` | `actor` | Thread-safe Firestore operations |
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

128 unit tests cover JSON decoding, model conversions, ViewModel logic, direction transition policies, undo behavior, deep link parsing, and display name validation. SwiftData tests use in-memory `ModelContainer`.

Firestore Security Rules are validated by a 78-test penetration testing suite (`security-tests/`) using `@firebase/rules-unit-testing` against the Firebase emulator. Tests cover ownership transfer attacks, size validation, schema validation, cross-user access attempts, type confusion attacks on `isActive`/`followedAt`/`description`/`ownerDisplayName`, `itemCount` consistency, and document size risks.

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

## Security: Firebase & Firestore

Firebase project configuration (API keys, project ID) is publicly extractable from the app binary. This is by design — Firebase API keys are not secrets. All authorization is enforced by Firestore Security Rules, which constitute the entire server-side authorization layer in this serverless architecture.

Security rules enforce owner-only access (`request.auth.uid == uid`) on all subcollections under `users/{uid}/`. Published lists have separate rules allowing public reads but owner-only writes. The rules include data validation on creates and updates: required fields, type checks, size limits (`name <= 200`, `items <= 500`, `description <= 2000`, `ownerDisplayName <= 200`), `isActive` bool enforcement, `itemCount` consistency with `items.size()`, `followedAt` timestamp enforcement, and immutable `ownerUID` protection.

Account deletion performs complete data erasure: Firebase Auth record, user profile document, all three private subcollections (`swipedItems`, `userLists`, `listEntries`), published list deactivation, and follow cleanup. Re-authentication is prompted on stale sessions instead of falling back to sign-out.

The 78-test penetration testing suite validates against ownership transfer attacks, cross-user data access, oversized document injection, schema violation attempts, type confusion attacks, and other attack vectors. Tests run against the Firebase emulator via `@firebase/rules-unit-testing`.
