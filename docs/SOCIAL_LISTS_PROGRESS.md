# FlickSwiper — Social Lists: Implementation Progress

**Feature Branch:** `feature/social-lists`
**Last Updated:** 2026-03-04

---

## Phase 1: Firebase Foundation

### Manual Setup (Must be done in Xcode / Firebase Console / Apple Developer)
- [x] Create Firebase project at console.firebase.google.com
- [x] Register iOS app in Firebase (bundle ID: com.flickswiper.app)
- [x] Download `GoogleService-Info.plist` → add to Xcode project (NOT to git)
- [x] Enable "Apple" as sign-in provider in Firebase Console → Authentication → Sign-in method
- [x] Add `firebase-ios-sdk` SPM dependency in Xcode (File > Add Packages > `https://github.com/firebase/firebase-ios-sdk.git`) — select **FirebaseAuth** and **FirebaseFirestore** only
- [x] Add "Sign in with Apple" capability in Xcode (Signing & Capabilities)
- [x] Verify app builds with Firebase imports

### Code
- [x] `AuthService.swift` — Sign in with Apple + Firebase Auth wrapper
- [x] `FirestoreService.swift` — Firestore CRUD for users, publishedLists, follows
- [x] `DisplayNameValidator.swift` — Offensive term check + format validation
- [x] `offensive_terms.json` — Bundled blocklist resource
- [x] Updated `.gitignore` — Added GoogleService-Info.plist
- [x] Updated `Constants.swift` — Added Firebase/deep link constants
- [x] Updated `FlickSwiperApp.swift` — Added FirebaseCore import, FirebaseApp.configure(), AuthService @State + .environment() injection
- [x] `DisplayNameValidatorTests.swift` — 12 tests: valid names, length bounds, trimming, newlines, PersonNameComponents fallback, error descriptions
- [x] `DeepLinkHandlerTests.swift` — 9 tests: valid links, wrong host, missing doc ID, wrong path, root path, listID extraction

### Verification
- [x] All unit tests passing (21 tests: 12 DisplayNameValidator + 9 DeepLinkHandler)
- [x] Can sign in with Apple → Firebase user created
- [x] User doc created in Firestore `users/{uid}`
- [x] Can publish a list → `publishedLists` doc created with correct data
- [x] Can read a published list back by doc ID

---

## Phase 2: Schema V3 Migration & Local Models
**Status:** Complete — shipped in v1.3

### Code
- [x] `FollowedList.swift` — SwiftData model for followed lists (firestoreDocID as unique key, ownerUID, isActive flag)
- [x] `FollowedListItem.swift` — SwiftData model for followed list items (tmdbID, mediaType, posterPath, sortOrder)
- [x] Updated `UserList.swift` — Added `firestoreDocID: String?`, `isPublished: Bool`, `lastSyncedAt: Date?` (all optional/defaulted)
- [x] Updated `SchemaVersions.swift` — Added `FlickSwiperSchemaV3`, updated `FlickSwiperMigrationPlan` with V2→V3 lightweight stage
- [x] Updated `FlickSwiperApp.swift` — Schema now includes FollowedList + FollowedListItem
- [x] Updated all `#Preview` containers — ContentView, FlickSwiperHomeView, SettingsView, SwipeView, SeenListView
- [x] Updated test schemas — SwipedItemStoreTests, SwipeViewModelTests

### Migration Safety Notes
- All new fields on `UserList` are optional with defaults → lightweight migration safe
- `FollowedList` and `FollowedListItem` are entirely new models → additive, no transformation needed
- **Critical test before submission:** Install current App Store V2 build → populate data → install V3 → verify zero data loss
- V2→V3 migration stage is `.lightweight` — SwiftData adds columns/tables automatically

---

## Phase 3: Publish Flow
**Status:** Complete — shipped in v1.3

### New Files
- [x] `Views/Social/SignInPromptView.swift` — Reusable auth prompt sheet with "Sign in with Apple" button, reason text, error handling
- [x] `Services/ListPublisher.swift` — Coordinator for publish/unpublish/sync: serializes ListEntry+SwipedItem → Firestore format, manages local UserList publish state
- [x] `Utils/ShareLinkSheet.swift` — UIActivityViewController wrapper for programmatic share sheet presentation

### Modified Files
- [x] `Views/Library/UserListCard.swift` — Link icon badge when `list.isPublished`, updated accessibility label
- [x] `Views/Library/MyListsSection.swift` — Context menu: "Share List" (unpublished) / "Copy Link" + "Unpublish" (published), auth check → SignInPromptView, publish loading overlay, unpublish confirmation dialog, Firestore cleanup on delete
- [x] `Views/Library/FilteredGridView.swift` — Toolbar menu: "Publish & Share" / "Share Link" when viewing a UserList, auth check, publish sheets, renamed existing share to "Share as Text"

### Publish Flow Summary
1. User taps "Share List" on unpublished list (context menu or toolbar)
2. If not signed in → SignInPromptView sheet → after sign-in, retries publish
3. ListPublisher fetches ListEntries + SwipedItems → serializes to Firestore PublishedListItem format
4. Writes to `publishedLists` collection → gets doc ID
5. Updates local UserList: `isPublished=true`, `firestoreDocID={docID}`
6. Opens share sheet with Universal Link URL

### Unpublish Flow
1. Confirmation dialog explains consequences to followers
2. Sets `isActive=false` in Firestore (soft delete)
3. Clears local `firestoreDocID` and `isPublished`
4. Re-publishing later creates NEW doc ID (per decision Q6)

---

## Phase 4: Universal Links & Deep Link Handling
**Status:** Complete — shipped in v1.3

### New Files (GitHub Pages / docs/)
- [x] `docs/.well-known/apple-app-site-association` — AASA file with appID `3P89U4WZAB.com.mitsheth.FlickSwiper`, paths: `/FlickSwiper/list/*`
- [x] `docs/_config.yml` — Jekyll config to include `.well-known` directory
- [x] `docs/list/index.html` — Fallback landing page for users without the app (App Store download link)
- [x] `docs/404.html` — Custom 404 that redirects `/FlickSwiper/list/{docID}` paths to the list landing page

### New Files (App Code)
- [x] `Utils/DeepLinkHandler.swift` — URL parser: extracts Firestore doc ID from Universal Link path, returns typed `Destination` enum
- [x] `Views/Social/SharedListView.swift` — Full deep link destination: fetches list from Firestore, shows name/owner/items grid, Follow button with auth gate, handles loading/error/deactivated states, creates local FollowedList + FollowedListItem on follow

### Modified Files
- [x] `ContentView.swift` — Added `.onOpenURL` handler that parses URL via DeepLinkHandler, presents SharedListView as sheet. Added `SharedListID` Identifiable wrapper for sheet binding.

### Manual Steps Required
- [x] Push `docs/` changes to GitHub → GitHub Pages serves AASA
- [x] Add Associated Domains entitlement in Xcode: `applinks:mit112.github.io`
- [x] Update App Store ID in `docs/list/index.html` and `docs/404.html`
- [x] Test on physical device

### Deep Link Flow
1. User taps `https://mit112.github.io/FlickSwiper/list/{docID}`
2. iOS intercepts → opens app → `.onOpenURL` fires
3. `DeepLinkHandler` parses doc ID → sets `sharedListDocID` state
4. `SharedListView` presented as sheet → fetches list from Firestore
5. Shows list content + "Follow" button (hidden if own list)
6. Follow creates Firestore `follows` doc + local `FollowedList` + `FollowedListItem` records
7. If app not installed → GitHub Pages 404 → redirects to list landing page → App Store link

### Note on Phase 5 Overlap
SharedListView already implements the core follow action (Firestore write + local cache creation), which is technically Phase 5 work. This was done here because the Follow button is integral to the shared list view and splitting it across phases would create an incomplete UX.

---

## Phase 5: Follow Flow & Real-Time Sync
**Status:** Code complete

### New Files
- [x] `Views/Social/FollowedListCard.swift` — Card for "Following" horizontal scroll: poster thumbnail, name, "by {owner}", item count, inactive badge
- [x] `Views/Social/FollowedListDetailView.swift` — Full grid view of followed list items. Read-only. Unfollow via toolbar menu with confirmation dialog. Deactivated banner for frozen lists. Notifies sync service on unfollow.
- [x] `Views/Library/FollowingSection.swift` — Horizontal scroll section for Library tab. Only renders when user follows ≥ 1 list. NavigationLink to FollowedListDetailView.
- [x] `Services/FollowedListSyncService.swift` — @Observable @MainActor service managing Firestore snapshot listeners. One listener per followed list doc. Updates local FollowedList + FollowedListItem on change. Activate/deactivate lifecycle tied to auth state.

### Modified Files
- [x] `FlickSwiperApp.swift` — Created `FollowedListSyncService`, injected via `.environment()`
- [x] `Views/Library/FlickSwiperHomeView.swift` — Added FollowingSection between Watchlist and Smart Collections. Added `.navigationDestination(for: FollowedList.self)`. Activates sync service on appear when signed in. Deactivates on sign-out.
- [x] `Views/Social/SharedListView.swift` — Calls `syncService.attachListener(for:)` after successful follow
- [x] `Views/Social/FollowedListDetailView.swift` — Calls `syncService.detachListener(for:)` after unfollow

### Real-Time Sync Architecture
- `FollowedListSyncService` is `@Observable` + `@MainActor`, injected at app root
- Activated when Library tab appears and user is signed in
- Scans all local `FollowedList` records, attaches one Firestore `addSnapshotListener` per doc
- On snapshot change: updates FollowedList metadata, deletes+recreates FollowedListItem records
- On `isActive == false`: marks local FollowedList as inactive, UI shows deactivated banner
- Deactivates (removes all listeners) on sign-out via `onChange(of: authService.isSignedIn)`
- Individual listeners attached/detached on follow/unfollow actions

### Follow flow (SharedListView, built in Phase 4)
1. Firestore `follows` doc created
2. Local FollowedList + FollowedListItem records created
3. Sync service listener attached

### Unfollow flow (FollowedListDetailView)
1. Confirmation dialog with explanation
2. Firestore `follows` doc deleted
3. Local FollowedListItem records deleted
4. Local FollowedList record deleted
5. Sync service listener detached
6. View dismisses

---

## Phase 6: Published List Sync (Owner Side)
**Status:** Code complete

### Approach
Fire-and-forget `ListPublisher.syncIfPublished(list:)` call after every successful `modelContext.save()` that modifies a published list's entries or name. If the list isn't published, the method returns immediately with zero overhead.

### Modified Files (sync hooks added)
- [x] `AddToListSheet.swift` — After toggle membership + after create-and-add
- [x] `BulkAddToListView.swift` — After apply changes
- [x] `AddSelectedToListSheet.swift` — After adding selected items
- [x] `FilteredGridView.swift` — After remove from list + after bulk delete (when sourceList != nil)
- [x] `MyListsSection.swift` — After rename

---

## Phase 7: Account Management & Settings
**Status:** Code complete

### Modified Files
- [x] `SettingsView.swift` — Complete Account section added at top of settings list:
  - **Signed in state:** Display name, Edit Display Name, Sign Out, Delete Account
  - **Signed out state:** "Sign In with Apple" button with "For list sharing" subtitle
  - Footer text explaining account purpose (signed in) or optionality (signed out)
  - Sign-in sheet (reuses `SignInPromptView`)
  - Edit display name alert (validates via `AuthService.updateDisplayName`)
  - Sign out confirmation dialog → deactivates sync service → calls `authService.signOut()`
  - Delete account confirmation → loading overlay → deactivates sync → cleans up local followed data → clears publish state on local lists → calls `authService.deleteAccount()` (Firestore cleanup + Firebase Auth deletion)

### Account Deletion Flow (Apple requirement)
1. Sync service deactivated (all Firestore listeners removed)
2. Local `FollowedList` + `FollowedListItem` records deleted
3. Local `UserList` publish state cleared (lists stay as local-only)
4. `AuthService.deleteAccount()` runs:
   a. Firestore batch: set all user's `publishedLists` to `isActive=false`
   b. Firestore batch: delete all user's `follows` docs
   c. Firestore: delete `users/{uid}` doc
   d. Firebase Auth: delete account
5. Auth state listener fires → UI updates to signed-out state

---

## Phase 8: Testing, Polish & Submission
**Status:** Complete — v1.3 published to App Store (March 2026)

### Completed Prep
- [x] Privacy policy updated (`docs/index.html`) — now documents Firebase Auth data collection, published list data, follow relationships, account deletion process, Firebase/Google privacy links
- [x] Firestore security rules prepared (`docs/firestore.rules`) — ready to copy-paste into Firebase Console. Includes data validation on creates, immutable follows, owner-only writes on published lists.

### Still Needed
- [x] Push `docs/` to GitHub (AASA file, fallback pages, updated privacy policy)
- [x] Deploy Firestore security rules to Firebase Console
- [ ] Create composite index: `follows` collection, `followerUID` ASC + `followedAt` DESC (Firebase may auto-prompt on first query)
- [x] Update App Store ID in `docs/list/index.html` and `docs/404.html`
- [x] V2 → V3 migration test (CRITICAL)
- [x] End-to-end testing of all flows on physical device
- [x] Accessibility audit on new views
- [x] Regression testing of existing features
- [x] Update App Store privacy label
- [x] Update App Store screenshots
- [x] Submit for review — **approved and published**

---

## Key Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-17 | Web fallback: static App Store redirect | Zero cost, zero security exposure |
| 2026-02-17 | Display names: Apple-provided + editable + validated | Blocklist for offensive terms, not unique |
| 2026-02-17 | Self-follow: blocked (no Follow button on own lists) | Client-side check only |
| 2026-02-17 | Owner deletes account: followed lists freeze | Less disruptive to followers |
| 2026-02-17 | Discovery: direct link only (v1) | In-app search deferred to v2 |
| 2026-02-17 | Re-publish: new Firestore doc ID | Clean break, unpublish means unpublish |

---

## Cross-Session Notes

- Firebase SDK version at time of implementation: latest stable (12.x)
- Using `OAuthProvider.appleCredential(withIDToken:rawNonce:fullName:)` for Apple auth
- Firestore `Codable` protocol used for type-safe document mapping
- `@Observable` pattern for AuthService (not ObservableObject — modern Swift)
- Actor-based FirestoreService for thread safety
