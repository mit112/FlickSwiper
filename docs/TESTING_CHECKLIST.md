# FlickSwiper — Physical Device Testing Checklist

Run these in order — each section builds on the previous one.
Items marked 🆕 are new for cloud sync / Google Sign-In.

**Last Updated:** 2026-02-21

---

## 0. Pre-flight

- [ ] Delete the app from your device if already installed (clean install to test migration later separately)
- [ ] Build and install from Xcode onto physical device
- [ ] App launches without crash
- [ ] All 4 tabs work (Discover, Search, Library, Settings)
- [ ] Existing features still work: swipe a few cards, search for a movie, check Library

---

## 1. Settings — Account Section (Signed Out)

- [ ] Settings tab shows "Account" section at the top
- [ ] Shows "Sign In with Apple" row with "For list sharing" subtitle
- [ ] Footer says signing in is optional

---

## 2. Sign In with Apple

- [ ] Tap "Sign In with Apple" in Settings
- [ ] SignInPromptView sheet appears with explanation text
- [ ] Tap the sign-in button → Apple sign-in sheet appears
- [ ] Complete sign-in (use real Apple ID or sandbox account)
- [ ] Sheet dismisses, Settings now shows "Signed in as {your name}"
- [ ] Check Firebase Console → Authentication → Users → your account appears
- [ ] Check Firebase Console → Firestore → `users` collection → document exists with your UID, displayName, createdAt

---

## 3. Settings — Account Section (Signed In)

- [ ] "Edit Display Name" row visible → tap it → alert with text field appears
- [ ] Change name → Save → name updates in the UI
- [ ] Check Firestore `users/{uid}` doc → displayName updated
- [ ] Try saving an empty name → should show error
- [ ] Try saving a 1-character name → should show "at least 2 characters" error
- [ ] "Sign Out" row visible
- [ ] "Delete Account" row visible (we'll test this last)

---

## 4. Create and Publish a List

- [ ] Go to Library tab → create a new list (e.g., "Test List")
- [ ] Add 3-5 items to the list (from detail views or bulk add)
- [ ] Long-press the list card → context menu shows "Share List"
- [ ] Tap "Share List" → loading overlay appears → share sheet opens with a URL
- [ ] Copy the URL — it should look like `https://mit112.github.io/FlickSwiper/list/{docID}`
- [ ] List card now shows a link icon (🔗) in the top-right corner
- [ ] Check Firestore Console → `publishedLists` collection → document exists with correct name, items array, ownerUID, isActive=true
- [ ] Long-press the list card again → context menu now shows "Copy Link" and "Unpublish" (not "Share List")

---

## 5. Publish from List Detail View

- [ ] Tap into a different (unpublished) list → toolbar ⋯ menu
- [ ] Menu shows "Publish & Share" option
- [ ] Tap it → publishes and opens share sheet
- [ ] Toolbar ⋯ menu now shows "Share Link" instead

---

## 6. Owner-Side Sync

- [ ] With a published list open, add a new item to it
- [ ] Check Firestore Console → the `publishedLists` doc → items array updated with the new item
- [ ] Remove an item from the published list
- [ ] Check Firestore → items array updated (item removed)
- [ ] Rename the published list (long-press → Rename)
- [ ] Check Firestore → name field updated

---

## 7. Universal Link (Same Device — Quick Test)

- [ ] Paste the copied link into Notes app
- [ ] Tap the link in Notes
- [ ] App should open directly to SharedListView (sheet with list name, "by {name}", items grid)
- [ ] Since this is your own list, the Follow button should NOT appear

---

## 8. Follow Flow (Needs a Second Device or Simulator)

If you have a second device or can test with a friend:

- [ ] Send the link to the second device
- [ ] Open link → app opens (or fallback page if not installed) → SharedListView appears
- [ ] List shows correct name, "by {owner name}", and all items
- [ ] "Follow This List" button is visible
- [ ] If not signed in → tapping Follow shows sign-in prompt → sign in → follow completes
- [ ] If signed in → tap Follow → button changes to "Following" ✓
- [ ] Go to Library tab → "Following" section appears with the followed list card
- [ ] Tap the followed list → FollowedListDetailView shows all items
- [ ] Check Firestore → `follows` collection → document exists with followerUID and listID

---

## 9. Real-Time Sync (Follower Side)

On the owner's device:
- [ ] Add a new item to the published list

On the follower's device:
- [ ] The followed list should update automatically (item appears without manual refresh)
- [ ] Item count on the card updates

---

## 10. Unfollow

On the follower's device:

- [ ] Open the followed list → toolbar ⋯ → "Unfollow"
- [ ] Confirmation dialog appears → tap "Unfollow"
- [ ] View dismisses, list disappears from "Following" section
- [ ] Check Firestore → `follows` document deleted

---

## 11. Unpublish

On the owner's device:

- [ ] Long-press published list → "Unpublish"
- [ ] Confirmation dialog warns about followers
- [ ] Tap "Unpublish" → link icon disappears from card
- [ ] Check Firestore → `publishedLists` doc → `isActive = false`
- [ ] If a follower had this list, they should see "This list is no longer maintained" banner
- [ ] Context menu reverts to showing "Share List" (would create a new link if tapped)

---

## 12. Delete a Published List

- [ ] Publish a list, then delete it (long-press → Delete)
- [ ] List disappears locally
- [ ] Check Firestore → doc set to `isActive = false`

---

## 13. Sign Out and Back In

- [ ] Settings → Sign Out → confirmation → confirm
- [ ] Account section reverts to "Sign In with Apple"
- [ ] Library → "Following" section should still show cached followed lists (if any)
- [ ] Sign back in → sync resumes, followed lists update

---

## 14. 🆕 Cloud Backup — Settings UI

- [ ] While signed in → Settings shows "Cloud Backup" section
- [ ] Shows sync status: "Synced X ago" after initial sync
- [ ] "Sync Now" button is visible and tappable
- [ ] Tap "Sync Now" → spinner appears, button disabled during sync
- [ ] After sync completes → "Synced just now" (or similar)
- [ ] Sign out → "Cloud Backup" section disappears
- [ ] Footer mentions automatic backup behavior

---

## 15. 🆕 Cloud Sync — First Sign-In + Basic Sync

- [ ] Start with swiped items + lists already in Library (from Pre-flight or earlier testing)
- [ ] Sign in → check Console logs for "Claiming unclaimed records"
- [ ] Open Firebase Console → `users/{uid}/swipedItems/*` has all your items
- [ ] `users/{uid}/userLists/*` has your lists
- [ ] `users/{uid}/listEntries/*` has your list entries
- [ ] Settings → "Cloud Backup" shows "Synced X ago"

---

## 16. 🆕 Cloud Sync — Individual Mutation Sync

- [ ] Swipe right (seen) → check Firestore doc created with `direction: "seen"`
- [ ] Swipe up (watchlist) → Firestore doc created with `direction: "watchlist"`
- [ ] Swipe left (skipped) → Firestore doc created with `direction: "skipped"`
- [ ] Rate an item → Firestore doc `personalRating` field updated
- [ ] Undo a swipe → Firestore doc reflects previous state (or deleted if new)
- [ ] Delete item from library → Firestore doc deleted

---

## 17. 🆕 Cloud Sync — List Mutation Sync

- [ ] Create a new list → `userLists/` doc appears in Firestore
- [ ] Rename a list → Firestore doc updated with new name + `lastModified`
- [ ] Delete a list → Firestore list doc AND all its entry docs deleted
- [ ] Add item to list via AddToListSheet → `listEntries/` doc created
- [ ] Remove item from list (toggle off) → entry doc deleted
- [ ] Bulk add items via AddSelectedToListSheet → all entry docs created

---

## 18. 🆕 Cloud Sync — Settings Reset Operations

- [ ] Reset Skipped Items → Firestore: all skipped swipedItem docs deleted
- [ ] Reset All Swiped Items → Firestore: all swipedItem + listEntry docs deleted
- [ ] Clear Watchlist → Firestore: watchlist item docs + related entry docs deleted

---

## 19. 🆕 Cloud Sync — Cross-Provider Account Switch (CRITICAL — was a bug)

- [ ] Signed in with Apple (Account A), has swiped items + lists in Library
- [ ] Sign out Apple
- [ ] Sign in with Google (Account B, different email)
- [ ] **Verify local library is EMPTY** (Account A's data cleared)
- [ ] Swipe a few items on Account B → verify they appear in Firestore under Account B's UID
- [ ] Sign out Google
- [ ] Sign back in with Apple (Account A)
- [ ] **Verify Account A's original data is restored from Firestore**
- [ ] Verify Account B's items are NOT visible

---

## 20. 🆕 Cloud Sync — Same Account Re-Sign-In

- [ ] Sign out → sign back in with **same** account
- [ ] All data still present locally — nothing cleared
- [ ] "Synced X ago" updates in Settings after re-sign-in

---

## 21. 🆕 Cloud Sync — Sync Lifecycle

- [ ] Force-quit app → relaunch while signed in → sync runs on launch (check Settings UI timestamp)
- [ ] Wait 5+ minutes with app in foreground → periodic sync fires (timestamp updates)

---

## 22. 🆕 Google Sign-In

- [ ] Sign out if signed in
- [ ] Tap "Sign In" → SignInPromptView shows both Apple and Google buttons with "or" divider
- [ ] Tap Google sign-in → Google OAuth flow launches
- [ ] Complete sign-in with Google account
- [ ] Settings shows "Signed in as {Google name}"
- [ ] Firebase Console → Authentication → Google account appears
- [ ] All features work same as Apple sign-in (publish, follow, cloud sync)

---

## 23. Account Deletion (Test Last!)

- [ ] Settings → Delete Account → confirmation dialog with warning text
- [ ] Confirm → loading overlay → account deleted
- [ ] Settings reverts to signed-out state
- [ ] Published lists are gone (isPublished cleared locally)
- [ ] Followed lists are gone locally
- [ ] Check Firestore → `users/{uid}` doc deleted
- [ ] Check Firestore → `publishedLists` docs → `isActive = false`
- [ ] Check Firestore → `follows` docs by this user → deleted
- [ ] Check Firebase Auth → user removed
- [ ] Can sign in fresh with a new account afterward

---

## 24. V2 → V4 Migration (CRITICAL — Do Separately)

- [ ] Install the current App Store version on device (V2 schema)
- [ ] Use it: swipe items, create lists, add items to lists, set ratings
- [ ] Note down: number of seen items, watchlist items, list names, items in lists
- [ ] Install the new build over it (don't delete the app)
- [ ] App launches without crash or "Data Reset Required" alert
- [ ] All seen items present with correct ratings
- [ ] All watchlist items present
- [ ] All custom lists present with correct items
- [ ] Smart collections still work
- [ ] Search still shows correct status indicators
- [ ] Sign in → data syncs to cloud correctly (new V4 fields get claimed)

---

## 25. Fallback Web Page

- [ ] Open `https://mit112.github.io/FlickSwiper/list/anything` in Safari on a device without the app
- [ ] Should show the "View this list in FlickSwiper" page with App Store link

---

## 26. Firestore Indexes

- [ ] After first sync, check Firebase Console → Firestore → Indexes
- [ ] If composite index prompts appear (for `lastModified` queries on subcollections), create them
- [ ] Create composite index: `follows` collection, `followerUID` ASC + `followedAt` DESC (if not auto-prompted)

---

## Edge Cases (if time permits)

- [ ] Publish an empty list (0 items) → should work, Firestore doc with empty items array
- [ ] Open a link with a fake/nonexistent doc ID → SharedListView shows "List not found"
- [ ] Airplane mode → try to publish → should fail gracefully with error message
- [ ] Airplane mode → open app with followed lists → cached data displays, no crash
- [ ] 🆕 Airplane mode → swipe items → disable airplane mode → verify queued writes land in Firestore
- [ ] 🆕 Create list while offline → add items → go online → list + entries sync

---

## Post-Testing Cleanup

- [ ] Update App Store privacy label (cloud sync changes data collection)
- [ ] Update App Store screenshots (if UI changed)
- [ ] Update App Store ID in `docs/list/index.html` and `docs/404.html`
- [ ] Commit all changes, push to GitHub
- [ ] Submit for App Store review
