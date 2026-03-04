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

## Step 6 — Testing Checklist

Prioritized: P0 = must pass before any release, P1 = important, P2 = nice to verify.

### P0 — Critical: First Sign-In + Basic Sync
- [ ] Fresh install, no account → swipe 3+ items, create a list, add items to it
- [ ] Sign in with Apple → check Console logs for "Claiming unclaimed records"
- [ ] Open Firebase Console → `users/{uid}/swipedItems/*` has all items
- [ ] `users/{uid}/userLists/*` and `users/{uid}/listEntries/*` populated
- [ ] Settings shows "Cloud Backup" section with "Synced X ago"

### P0 — Critical: Cross-Provider Account Switch (the bug we fixed)
- [ ] Signed in with Apple (Account A), has swiped items + lists
- [ ] Sign out Apple
- [ ] Sign in with Google (Account B, different email) → **verify local library is empty** (Account A data cleared)
- [ ] Swipe a few items on Account B → verify they appear in Firestore under Account B's UID
- [ ] Sign out Google → sign back in with Apple (Account A) → **verify Account A's original data is restored from Firestore**
- [ ] Verify Account B's items are NOT visible

### P0 — Critical: Same Account Re-Sign-In
- [ ] Sign out → sign back in with **same** account → all data still present locally, nothing cleared
- [ ] "Synced X ago" updates in Settings after re-sign-in

### P1 — Individual Mutation Sync
- [ ] Swipe right (seen) → Firestore doc created with `direction: "seen"`
- [ ] Swipe up (watchlist) → Firestore doc created with `direction: "watchlist"`
- [ ] Swipe left (skipped) → Firestore doc created with `direction: "skipped"`
- [ ] Rate an item → Firestore doc `personalRating` field updated
- [ ] Undo a swipe → Firestore doc reflects previous state (or deleted if it was new)
- [ ] Delete item from library → Firestore doc deleted

### P1 — List Mutation Sync
- [ ] Create a new list → `userLists/` doc appears in Firestore
- [ ] Rename a list → Firestore doc updated with new name + `lastModified`
- [ ] Delete a list → Firestore list doc AND all its entry docs deleted
- [ ] Add item to list via AddToListSheet → `listEntries/` doc created
- [ ] Remove item from list (toggle off) → entry doc deleted
- [ ] Bulk add items via AddSelectedToListSheet → all entry docs created

### P1 — Settings Reset Operations
- [ ] Reset Skipped Items → Firestore: all skipped swipedItem docs deleted
- [ ] Reset All Swiped Items → Firestore: all swipedItem + listEntry docs deleted
- [ ] Clear Watchlist → Firestore: watchlist item docs + related entry docs deleted

### P1 — Sync Lifecycle
- [ ] Force-quit app → relaunch while signed in → sync runs on launch (check Settings UI)
- [ ] "Sync Now" button triggers sync, shows spinner, then "Synced X ago"
- [ ] "Sync Now" disabled while syncing
- [ ] Wait 5+ minutes with app in foreground → periodic sync fires

### P2 — Offline / Queuing
- [ ] Airplane mode → swipe several items → disable airplane mode → verify writes land in Firestore
- [ ] Create list while offline → add items → go online → list + entries sync

### P2 — Direction Merge Protection (needs 2 devices or simulated conflict)
- [ ] Device A: mark item as "seen"
- [ ] Device B (same account): mark same item as "watchlist" (newer timestamp)
- [ ] Sync Device A → item stays "seen" (hierarchy prevents demotion)

### P2 — Account Deletion
- [ ] Delete account → local followed lists/items cleared
- [ ] Published lists marked inactive in Firestore
- [ ] Can sign in fresh with new account afterward

### P2 — Edge Cases
- [ ] Sign in → force-quit before sync completes → relaunch → sync recovers
- [ ] Two devices simultaneously: both add different items → sync both → no data loss
- [ ] Firestore composite index prompt: run first sync, check Firebase Console for auto-suggested indexes, create them if prompted
