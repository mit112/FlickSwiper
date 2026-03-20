# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build (iOS Simulator)
xcodebuild build \
  -project FlickSwiper.xcodeproj \
  -scheme FlickSwiper \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO

# Run all tests
xcodebuild test \
  -project FlickSwiper.xcodeproj \
  -scheme FlickSwiper \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO

# Run a single test class
xcodebuild test \
  -project FlickSwiper.xcodeproj \
  -scheme FlickSwiper \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -only-testing:FlickSwiperTests/SwipeViewModelTests \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO

# Firestore security rules tests (requires Firebase emulator)
cd security-tests && npm run test:emulator

# Coverage report (after test run)
xcrun xccov view --report TestResults.xcresult
```

**API key setup:** Copy `FlickSwiper/Config/Secrets.xcconfig.template` to `Secrets.xcconfig` and add your TMDB API Read Access Token. CI creates a placeholder automatically.

## Architecture

**MVVM with @Observable** — Views bind to ViewModels, ViewModels coordinate Services and SwiftData.

| Layer | Isolation | Examples |
|-------|-----------|---------|
| Views (SwiftUI) | — | MovieCardView, LibraryView |
| ViewModels (@Observable) | @MainActor | SwipeViewModel, SearchViewModel |
| Services | actor or @MainActor | TMDBService (actor), CloudSyncService (@MainActor) |
| Persistence | SwiftData | SwipedItem, UserList, ListEntry |
| Remote | Firebase | Firestore (sync/social), FirebaseAuth |

**Key service roles:**
- `TMDBService` — actor-isolated TMDB API client with rate-limit retry (429 handling)
- `CloudSyncService` — push-on-write + incremental pull (5-min interval), timestamp-based merge
- `AuthService` — Firebase Auth (Apple + Google Sign-In)
- `FirestoreService` — actor-isolated Firestore CRUD
- `ListPublisher` — publish/unpublish social lists to Firestore
- `FollowedListSyncService` — per-list Firestore snapshot listeners
- `SwipedItemStore` — centralized write operations, enforces direction transition policy

## Critical Design Decisions

**UUID-based joins, not SwiftData @Relationship.** `UserList` ↔ `ListEntry` ↔ `SwipedItem` are linked by UUID strings. This avoids known SwiftData relationship bugs in iOS 17.x.

**Frozen VersionedSchema definitions (V1→V4).** Each schema version in `SchemaVersions.swift` contains exact model snapshots. Never modify a frozen schema — add a new version. All new fields must be `Optional` with defaults for lightweight migration.

**Direction transition policy.** Hierarchy: seen (2) > watchlist (1) > skipped (0). Promotions allowed, demotions silently ignored. Enforced in both `SwipedItemStore` and `SwipeViewModel`. Undo uses `UndoEntry` with `previousDirection`.

**Cloud sync merge rule.** Most-recent `lastModified` wins, but direction hierarchy is never violated. Batch uploads chunked at 400 ops (under Firestore's 500 limit). `syncIfNeeded` has a re-entrancy guard (`syncState != .syncing`) to prevent overlapping sync operations.

**Account deletion.** Deletes Firebase Auth record first (with re-auth on stale session), then all Firestore data: published lists deactivated, follows deleted, profile deleted, all three private subcollections (`swipedItems`, `userLists`, `listEntries`) batch-deleted. Local data cleared only after Firebase succeeds.

**Image caching.** Enlarged `URLCache.shared` (50MB memory / 200MB disk) instead of third-party libraries. `RetryAsyncImage` handles transient failures with up to 2 retries.

## Testing Conventions

- Tests use `@MainActor` for SwiftUI state management tests
- SwiftData tests use in-memory `ModelContainer` (no disk persistence)
- `MockMediaService` (conforms to `MediaServiceProtocol`) enables DI in ViewModel tests
- CI enforces 30% minimum line coverage threshold
- Security rules have a separate Jest test suite in `security-tests/` (78 tests)

## Code Conventions

- `direction` stored as raw `String` ("seen", "skipped", "watchlist"), not an enum or integer
- `SwipedItem.uniqueID` format: `"{mediaType}_{mediaID}"` — serves as the dedup key
- Search uses 400ms debounce via Task cancellation pattern
- Keep `print()` wrapped in `#if DEBUG`; prefer `OSLog Logger` for production logging
- Commit messages use imperative mood with intent prefix: `Fix:`, `Add:`, `Feat:`, etc.

## Dependencies

SPM only: `FirebaseAuth`, `FirebaseFirestore`, `GoogleSignIn`, `GoogleSignInSwift`. No external UI frameworks — native SwiftUI exclusively.
