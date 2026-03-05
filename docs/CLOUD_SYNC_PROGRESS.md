# Cloud Sync Implementation Progress

## Overview
Adding bidirectional cloud sync to FlickSwiper so users can back up and restore their library across devices via Firebase Auth (Apple + Google Sign-In).

**Architecture**: Push-on-write + incremental pull (modeled on StreakSync's `FirestoreGameResultSyncService`). Firestore offline persistence handles queuing. Merge rule: most recent `lastModified` wins, but direction hierarchy (seen > watchlist > skipped) is never violated.

**Firestore structure**:
```
users/{uid}/swipedItems/{uniqueID}    ← "movie_550"
users/{uid}/userLists/{uuid}
users/{uid}/listEntries/{uuid}
```

**Account switch strategy**: On different-account sign-in, sync current data to cloud first, then clear local data, then pull new account's data. No multi-account coexistence in SwiftData (uniqueID collision problem).

**Users upgrading from**: V2 schema (no Firebase at all). This release ships V2→V3→V4 migration chain.

---

## Build Status

✅ **BUILD SUCCEEDED** (Feb 20, 2026) — iPhone 17 Pro Max Simulator, Swift 6, Release config. 6 warnings (Sendable captures in CloudSyncService — non-fatal). Zero errors.

✅ **v1.3 PUBLISHED TO APP STORE** (March 2026) — Cloud sync shipped as part of the v1.3 release alongside social lists and UI refresh. Testing checklist below reflects pre-release status; items not checked off were either deferred or tested informally without updating this doc.

---

## Completed

### Google Sign-In (fully done)
- `AuthService.swift` — `signInWithGoogle()`, `handleGoogleSignInURL()`, provider-aware `signOut()` and `deleteAccount()`, `accountExistsWithDifferentProvider` collision error
- `SignInPromptView.swift` — Apple + Google buttons with "or" divider
- `ContentView.swift` — `onOpenURL` routes Google OAuth before deep links
- `FlickSwiperApp.swift` — `import GoogleSignIn`
- `SettingsView.swift` — "Sign In" (generic), updated footer text
- `Info.plist` — URL scheme for reversed client ID
- `GoogleService-Info.plist` — Has CLIENT_ID and REVERSED_CLIENT_ID
- SPM: `GoogleSignIn-iOS` 9.1.0 resolved

### Schema V4 Migration (fully done)
- `SwipedItem.swift` — Added `lastModified: Date?`, `ownerUID: String?`. Init sets `lastModified = Date()`, `ownerUID = nil`
- `UserList.swift` — Same two fields added
- `ListEntry.swift` — Same two fields added
- `SchemaVersions.swift` — V3 frozen with all 5 model copies (SwipedItem, UserList, ListEntry, FollowedList, FollowedListItem). V4 added as current. Migration plan has `migrateV3toV4` lightweight stage.
- **Note**: FollowedList/FollowedListItem intentionally NOT changed — they're Firestore cache data

### CloudSyncService.swift (fully done — 707 lines)
- `SyncState` enum (idle/syncing/synced/failed)
- `claimUnownedRecords(uid:context:)` — stamps nil ownerUID records on first sign-in
- `syncIfNeeded(context:)` — bidirectional sync entry point
- `pullAndMerge()` — incremental fetch via `lastModified > lastSyncTimestamp`
- `mergeSwipedItems/mergeUserLists/mergeListEntries` — timestamp-based merge with direction hierarchy protection
- `pushLocalChanges()` — pushes modified records since last sync
- `batchUpload*` — chunked at 400 ops (under Firestore 500 limit)
- `pushSwipedItem/pushUserList/pushListEntry` — write-through for individual mutations
- `deleteSwipedItem/deleteUserList/deleteListEntry` — Firestore delete on local delete
- `bulkDeleteSwipedItems/bulkDeleteListEntries` — for Settings reset operations
- `handleAccountSwitch(newUID:context:)` — clear local + pull new account
- `currentUserUID` computed property (for SwipedItemStore to stamp ownerUID)
- `toFirestoreData()` extensions on SwipedItem, UserList, ListEntry
- `Array.chunked(into:)` utility

### SwipedItem Mutation Hooks (fully done)
All SwipedItem write paths now set `lastModified = Date()`, `ownerUID`, and push to cloud:

**SwipedItemStore.swift** — rewritten with `cloudSync: CloudSyncService?` parameter. All 5 methods (markAsSeen, saveToWatchlist, moveWatchlistToSeen, remove, setPersonalRating) have sync hooks.

**SwipeViewModel.swift** — `cloudSync` property added. All 4 mutation methods (swipeRight, swipeLeft, swipeUp, undoLastSwipe) set lastModified/ownerUID and push.

**View files updated** (all pass `cloudSync: cloudSync` to SwipedItemStore):
- SwipeView.swift — `@Environment(CloudSyncService.self)` + rating prompt
- SearchView.swift — 3 calls (markAsSeen, saveToWatchlist, setPersonalRating)
- WatchlistRatingSheet.swift — 1 call (setPersonalRating via moveWatchlistToSeen + rate)
- WatchlistGridView.swift — 2 calls (markAsSeen, remove)
- FilteredGridView.swift — 2 calls (moveWatchlistToSeen, remove)
- FlickSwiperHomeView.swift — 2 calls (moveWatchlistToSeen, remove)

**Verified**: Zero remaining `SwipedItemStore(context: modelContext)` calls without cloudSync parameter.

### UserList / ListEntry Mutation Hooks (fully done)
All list write paths now set `ownerUID`, `lastModified`, and push to cloud:

**SettingsView.swift** — `@Environment(CloudSyncService.self)` added.
- `resetSkippedItems()` — collects IDs before delete, calls `bulkDeleteSwipedItems` + `bulkDeleteListEntries`
- `resetAllSwipedItems()` — gathers all item/entry IDs, calls both bulk deletes
- `resetWatchlistItems()` — same pattern for watchlist items
- `performSignOut()` — calls `syncIfNeeded()` before sign-out to push pending changes
- `performAccountDeletion()` — calls `syncIfNeeded()` before deletion (best-effort final sync)
- New `collectEntryIDs(for:)` helper — gathers entry UUIDs before deleting items
- Cloud Backup section in Settings UI — shows sync status + "Sync Now" button

**MyListsSection.swift** — `@Environment(CloudSyncService.self)` added.
- Create list: sets `ownerUID`, pushes `pushUserList()`
- Rename list: sets `lastModified = Date()`, pushes `pushUserList()`
- Delete list: collects entry IDs, calls `deleteUserList(listID:entryIDs:)`

**AddToListSheet.swift** — `@Environment(CloudSyncService.self)` added.
- Create list + entry: stamps both with `ownerUID`, pushes both
- Toggle membership (add): creates entry with `ownerUID`, pushes entry + updates list
- Toggle membership (remove): calls `deleteListEntry(entryID:)`, updates list lastModified

**AddSelectedToListSheet.swift** — `@Environment(CloudSyncService.self)` added.
- Bulk add: stamps each new `ListEntry` with `ownerUID`, pushes each entry + list

### App Wiring (fully done)

**FlickSwiperApp.swift**:
- `@State private var cloudSyncService = CloudSyncService()`
- Injected via `.environment(cloudSyncService)` on ContentView

**ContentView.swift**:
- `@Environment(CloudSyncService.self)` + `@Environment(\.modelContext)`
- `@State private var previousUID: String?` for account switch detection
- `.onChange(of: authService.currentUser?.uid)` → `handleAuthChange()`:
  - nil→UID: `claimUnownedRecords()` + `syncIfNeeded()`
  - UID→nil: clears previousUID
  - UID_A→UID_B: `handleAccountSwitch()`
- `.task` block: initial sync on launch + periodic sync every 5 minutes
- Preview updated with all environment objects

### Firestore Rules (fully done)
`docs/firestore.rules` — added subcollection rules nested under `users/{uid}`:
```
match /swipedItems/{itemId} { allow read, write: if auth.uid == uid; }
match /userLists/{listId}   { allow read, write: if auth.uid == uid; }
match /listEntries/{entryId} { allow read, write: if auth.uid == uid; }
```

### Settings UI (fully done)
- "Cloud Backup" section visible when signed in
- Sync status row: Idle / Syncing… (with spinner) / "Synced X ago" / Failed
- "Sync Now" button (disabled during sync)
- Footer explains auto-sync behavior
- Account section footer updated to mention backup

---

## Known Issues / Future Work

1. **Account deletion Firestore cleanup**: When a user deletes their account, the subcollection data (swipedItems, userLists, listEntries) is orphaned in Firestore. Client SDK cannot recursively delete subcollections. **Solution**: Deploy a Cloud Function triggered on `auth.user().onDelete()` to clean up subcollections. Low priority — the data is inaccessible (security rules block it) and doesn't affect user experience.

2. **Preview providers**: ✅ FIXED — SwipeView and FlickSwiperHomeView previews updated with `.environment(CloudSyncService())`. The other 7 files with `@Environment(CloudSyncService.self)` (SearchView, WatchlistRatingSheet, WatchlistGridView, FilteredGridView, MyListsSection, AddToListSheet, AddSelectedToListSheet) don't have `#Preview` blocks, so no fix needed. ContentView and SettingsView were already fixed.

3. **ContentView build fix**: ✅ FIXED — Added `import FirebaseAuth` to ContentView.swift. The `.uid` property on `authService.currentUser` requires this import (Swift 6 `MemberImportVisibility` feature flag makes this explicit).

4. **CloudSyncService Sendable warnings**: `pushSwipedItem/pushUserList/pushListEntry` capture `@Model` objects in `@Sendable` closures. SwiftData models are not `Sendable`. These are warnings only, not errors. Fix later by extracting Firestore data dictionaries on the main actor before dispatching to background.

5. **Cross-provider account switch bug**: ✅ FIXED — When user signed out Account A (Apple) then signed in Account B (Google), the nil→UID path called `claimUnownedRecords` which did nothing (records had `ownerUID = UID_A`, not nil). Account A's data remained visible in the UI but didn't sync to Account B. Fix: `handleAuthChange` now checks for foreign-owned records before choosing between claim (same/new account) vs `handleAccountSwitch` (different account data present).

6. **Firestore indexes**: The `lastModified` field is used in inequality queries (`whereField("lastModified", isGreaterThan:)`). Firestore may require composite indexes for these subcollections. Firebase usually auto-suggests them on first query failure — deploy rules and run a sync to trigger the prompts.

---

## Step 6 — Testing

All P0 and P1 scenarios (first sign-in sync, cross-provider account switch, same-account re-sign-in, individual mutation sync, list mutation sync, settings reset operations, sync lifecycle) were verified on physical device before the v1.3 App Store submission. P2 scenarios (offline queuing, direction merge protection, account deletion cleanup, edge cases) were partially verified; remaining items are tracked in Known Issues above.
