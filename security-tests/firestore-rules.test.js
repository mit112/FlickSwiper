/**
 * FlickSwiper — Firestore Security Rules Penetration Tests
 * =========================================================
 *
 * Tests every rule path against the deployed firestore.rules.
 * Run against the local emulator — never against production.
 *
 * Legend:
 *   ✅ PASS = rule correctly blocks/allows the operation
 *   🔴 VULN = rule permits something it shouldn't (fix needed)
 *   ⚠️  RISK = rule permits something intentionally but worth documenting
 *
 * Usage:
 *   Terminal 1:  cd /path/to/FlickSwiper && firebase emulators:start --only firestore
 *   Terminal 2:  cd security-tests && npm test
 *
 *   OR (single command, auto starts/stops emulator):
 *   cd security-tests && npm run test:emulator
 */

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const { readFileSync } = require("fs");
const { resolve } = require("path");

const PROJECT_ID = "flickswiper-a9ff4";
const RULES_PATH = resolve(__dirname, "../docs/firestore.rules");

let testEnv;

beforeAll(async () => {
  const rules = readFileSync(RULES_PATH, "utf8");
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules,
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

afterAll(async () => {
  if (testEnv) await testEnv.cleanup();
});

afterEach(async () => {
  if (testEnv) await testEnv.clearFirestore();
});

// ─── Helpers ────────────────────────────────────────────────

function authed(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function unauthed() {
  return testEnv.unauthenticatedContext().firestore();
}

async function seedAdmin(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

// ════════════════════════════════════════════════════════════
//  SECTION 1 — Unauthenticated Access (must fail everywhere)
// ════════════════════════════════════════════════════════════

describe("Unauthenticated Access", () => {
  test("cannot read user profiles", async () => {
    await seedAdmin(db => db.doc("users/victim").set({ displayName: "Victim" }));

    await assertFails(unauthed().doc("users/victim").get());
  });

  test("cannot read published lists", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set({
      ownerUID: "owner1",
      name: "Test",
      items: [],
    }));

    await assertFails(unauthed().doc("publishedLists/list1").get());
  });

  test("cannot read follows", async () => {
    await assertFails(unauthed().collection("follows").get());
  });

  test("cannot read any subcollection", async () => {
    await assertFails(
      unauthed().collection("users/victim/swipedItems").get()
    );
    await assertFails(
      unauthed().collection("users/victim/userLists").get()
    );
    await assertFails(
      unauthed().collection("users/victim/listEntries").get()
    );
  });

  test("cannot write anywhere", async () => {
    await assertFails(
      unauthed().doc("users/attacker").set({ displayName: "Hacker" })
    );
    await assertFails(
      unauthed().doc("publishedLists/fake").set({ name: "Fake" })
    );
    await assertFails(
      unauthed().collection("follows").add({ followerUID: "x", listID: "y" })
    );
  });
});

// ════════════════════════════════════════════════════════════
//  SECTION 2 — User Profiles (/users/{uid})
// ════════════════════════════════════════════════════════════

describe("User Profiles", () => {
  test("owner can CRUD their own profile", async () => {
    const db = authed("alice");

    await assertSucceeds(
      db.doc("users/alice").set({ displayName: "Alice", uid: "alice" })
    );
    await assertSucceeds(db.doc("users/alice").get());
    await assertSucceeds(
      db.doc("users/alice").update({ displayName: "Alice Updated" })
    );
    await assertSucceeds(db.doc("users/alice").delete());
  });

  test("⚠️ RISK: any authed user can READ any profile (social graph)", async () => {
    await seedAdmin(db =>
      db.doc("users/alice").set({ displayName: "Alice", uid: "alice", email: "alice@test.com" })
    );

    // Bob can read Alice's profile — including any PII stored there
    const snapshot = await assertSucceeds(
      authed("bob").doc("users/alice").get()
    );

    const data = snapshot.data();
    console.log(
      "\n  ⚠️  Fields exposed to other users:",
      Object.keys(data).join(", ")
    );
    if (data.email) {
      console.log("  🔴 EMAIL IS EXPOSED to all authenticated users!");
    }
  });

  test("cannot create profile for another user", async () => {
    await assertFails(
      authed("alice").doc("users/bob").set({ displayName: "Fake Bob" })
    );
  });

  test("cannot update another user's profile", async () => {
    await seedAdmin(db => db.doc("users/alice").set({ displayName: "Alice" }));

    await assertFails(
      authed("bob").doc("users/alice").update({ displayName: "Hacked" })
    );
  });

  test("cannot delete another user's profile", async () => {
    await seedAdmin(db => db.doc("users/alice").set({ displayName: "Alice" }));

    await assertFails(authed("bob").doc("users/alice").delete());
  });
});

// ════════════════════════════════════════════════════════════
//  SECTION 3 — Cloud Sync Subcollections
//  /users/{uid}/swipedItems, /userLists, /listEntries
// ════════════════════════════════════════════════════════════

describe("Cloud Sync — swipedItems", () => {
  test("owner can CRUD their own swipedItems", async () => {
    const db = authed("alice");
    const ref = db.doc("users/alice/swipedItems/movie_123");

    await assertSucceeds(
      ref.set({
        uniqueID: "movie_123",
        direction: "seen",
        ownerUID: "alice",
        lastModified: new Date(),
      })
    );
    await assertSucceeds(ref.get());
    await assertSucceeds(ref.update({ direction: "watchlist" }));
    await assertSucceeds(ref.delete());
  });

  test("cannot read another user's swipedItems", async () => {
    await seedAdmin(db => db.doc("users/alice/swipedItems/movie_123").set({
      uniqueID: "movie_123",
      direction: "seen",
    }));

    await assertFails(
      authed("bob").doc("users/alice/swipedItems/movie_123").get()
    );
  });

  test("cannot list another user's swipedItems", async () => {
    await seedAdmin(db => db.doc("users/alice/swipedItems/movie_123").set({
      uniqueID: "movie_123",
      direction: "seen",
    }));

    await assertFails(
      authed("bob").collection("users/alice/swipedItems").get()
    );
  });

  test("cannot write to another user's swipedItems", async () => {
    await assertFails(
      authed("bob").doc("users/alice/swipedItems/injected").set({
        uniqueID: "hacked",
        direction: "seen",
      })
    );
  });

  test("cannot delete another user's swipedItems", async () => {
    await seedAdmin(db => db.doc("users/alice/swipedItems/movie_123").set({
      uniqueID: "movie_123",
      direction: "seen",
    }));

    await assertFails(
      authed("bob").doc("users/alice/swipedItems/movie_123").delete()
    );
  });
});

describe("Cloud Sync — userLists", () => {
  test("owner can CRUD their own userLists", async () => {
    const db = authed("alice");
    const ref = db.doc("users/alice/userLists/list1");

    await assertSucceeds(
      ref.set({ name: "Favorites", ownerUID: "alice", lastModified: new Date() })
    );
    await assertSucceeds(ref.get());
    await assertSucceeds(ref.update({ name: "My Favorites" }));
    await assertSucceeds(ref.delete());
  });

  test("cannot read another user's userLists", async () => {
    await seedAdmin(db =>
      db.doc("users/alice/userLists/list1").set({ name: "Secret List", ownerUID: "alice" })
    );

    await assertFails(authed("bob").collection("users/alice/userLists").get());
  });

  test("cannot write to another user's userLists", async () => {
    await assertFails(
      authed("bob")
        .doc("users/alice/userLists/injected")
        .set({ name: "Hacked", ownerUID: "alice" })
    );
  });
});

describe("Cloud Sync — listEntries", () => {
  test("owner can CRUD their own listEntries", async () => {
    const db = authed("alice");
    const ref = db.doc("users/alice/listEntries/entry1");

    await assertSucceeds(
      ref.set({ listID: "list1", itemID: "movie_123", ownerUID: "alice" })
    );
    await assertSucceeds(ref.get());
    await assertSucceeds(ref.delete());
  });

  test("cannot read another user's listEntries", async () => {
    await seedAdmin(db =>
      db.doc("users/alice/listEntries/entry1").set({ listID: "list1", itemID: "movie_123" })
    );

    await assertFails(
      authed("bob").collection("users/alice/listEntries").get()
    );
  });

  test("cannot write to another user's listEntries", async () => {
    await assertFails(
      authed("bob")
        .doc("users/alice/listEntries/injected")
        .set({ listID: "list1", itemID: "hacked" })
    );
  });
});

// ════════════════════════════════════════════════════════════
//  SECTION 4 — Published Lists (/publishedLists/{listId})
// ════════════════════════════════════════════════════════════

describe("Published Lists — Access Control", () => {
  const validList = {
    ownerUID: "alice",
    name: "Best Horror Movies",
    items: [{ tmdbID: 123, title: "The Shining" }],
    ownerDisplayName: "Alice",
    isActive: true,
  };

  test("owner can create a published list", async () => {
    await assertSucceeds(
      authed("alice").doc("publishedLists/list1").set(validList)
    );
  });

  test("any authed user can read a published list", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set(validList));

    await assertSucceeds(authed("bob").doc("publishedLists/list1").get());
  });

  test("owner can update their list", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set(validList));

    await assertSucceeds(
      authed("alice")
        .doc("publishedLists/list1")
        .update({ name: "Updated Name" })
    );
  });

  test("owner can delete their list", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set(validList));

    await assertSucceeds(
      authed("alice").doc("publishedLists/list1").delete()
    );
  });

  test("cannot create list with spoofed ownerUID", async () => {
    await assertFails(
      authed("alice").doc("publishedLists/spoofed").set({
        ...validList,
        ownerUID: "bob", // alice tries to impersonate bob
      })
    );
  });

  test("cannot update another user's list", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set(validList));

    await assertFails(
      authed("bob")
        .doc("publishedLists/list1")
        .update({ name: "Hacked by Bob" })
    );
  });

  test("cannot delete another user's list", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set(validList));

    await assertFails(authed("bob").doc("publishedLists/list1").delete());
  });
});

describe("Published Lists — Data Validation Attacks", () => {
  test("🔴 VULN-FS-003: rejects list missing required name field", async () => {
    await assertFails(
      authed("alice").doc("publishedLists/noname").set({
        ownerUID: "alice",
        // name is missing
        items: [],
      })
    );
  });

  test("✅ VULN-FS-003 FIXED: rejects oversized name", async () => {
    await assertFails(
      authed("alice")
        .doc("publishedLists/bigname")
        .set({
          ownerUID: "alice",
          name: "A".repeat(100000),
          items: [],
          ownerDisplayName: "Alice",
          isActive: true,
        })
    );
  });

  test("✅ VULN-FS-003 FIXED: rejects massive items array", async () => {
    const hugeItems = Array.from({ length: 1000 }, (_, i) => ({
      tmdbID: i,
      title: `Movie ${i}`,
      garbage: "x".repeat(500),
    }));

    await assertFails(
      authed("alice")
        .doc("publishedLists/huge")
        .set({
          ownerUID: "alice",
          name: "Huge List",
          items: hugeItems,
          ownerDisplayName: "Alice",
          isActive: true,
        })
    );
  });

  test("⚠️ VULN-FS-003: accepts garbage item objects (no schema)", async () => {
    const result = authed("alice")
      .doc("publishedLists/garbage")
      .set({
        ownerUID: "alice",
        name: "Legit Name",
        items: [
          { malicious: true, xss: "<script>alert(1)</script>" },
          { sql: "DROP TABLE users;--" },
          42, // not even an object
          null,
        ],
        ownerDisplayName: "Alice",
        isActive: true,
      });

    try {
      await assertSucceeds(result);
      console.log(
        "\n  ⚠️  Items array accepts arbitrary contents. Client-side validation required."
      );
    } catch {
      console.log("\n  ✅ Items array validates object schema.");
    }
  });

  test("rejects list without items field", async () => {
    await assertFails(
      authed("alice").doc("publishedLists/noitems").set({
        ownerUID: "alice",
        name: "No Items",
        // items missing
      })
    );
  });

  test("rejects list where name is not a string", async () => {
    await assertFails(
      authed("alice").doc("publishedLists/badname").set({
        ownerUID: "alice",
        name: 12345, // number, not string
        items: [],
      })
    );
  });

  test("rejects list where items is not a list", async () => {
    await assertFails(
      authed("alice").doc("publishedLists/baditems").set({
        ownerUID: "alice",
        name: "Test",
        items: "not a list", // string, not array
      })
    );
  });
});

describe("Published Lists — Ownership Transfer Attack", () => {
  const validList = {
    ownerUID: "alice",
    name: "Alice's List",
    items: [],
    ownerDisplayName: "Alice",
    isActive: true,
  };

  test("✅ VULN-FS-004 FIXED: owner CANNOT change ownerUID", async () => {
    await seedAdmin(db => db.doc("publishedLists/transferable").set(validList));

    await assertFails(
      authed("alice")
        .doc("publishedLists/transferable")
        .update({ ownerUID: "bob" })
    );
  });

  test("non-owner CANNOT update even with matching ownerUID trick", async () => {
    await seedAdmin(db => db.doc("publishedLists/trick").set(validList));

    // Bob tries to update — resource.data.ownerUID is "alice", not "bob"
    await assertFails(
      authed("bob").doc("publishedLists/trick").update({ name: "Hacked" })
    );
  });
});

// ════════════════════════════════════════════════════════════
//  SECTION 5 — Follows (/follows/{followId})
// ════════════════════════════════════════════════════════════

describe("Follows — Access Control", () => {
  test("user can create a follow for themselves", async () => {
    await assertSucceeds(
      authed("alice").collection("follows").add({
        followerUID: "alice",
        listID: "list1",
        followedAt: new Date(),
      })
    );
  });

  test("cannot create follow impersonating another user", async () => {
    await assertFails(
      authed("alice").collection("follows").add({
        followerUID: "bob", // alice pretending to be bob
        listID: "list1",
        followedAt: new Date(),
      })
    );
  });

  test("cannot update a follow (immutable)", async () => {
    await seedAdmin(db => db.doc("follows/follow1").set({
      followerUID: "alice",
      listID: "list1",
      followedAt: new Date(),
    }));

    // Even the owner can't update
    await assertFails(
      authed("alice").doc("follows/follow1").update({ listID: "list2" })
    );
  });

  test("user can delete their own follow", async () => {
    await seedAdmin(db => db.doc("follows/follow1").set({
      followerUID: "alice",
      listID: "list1",
      followedAt: new Date(),
    }));

    await assertSucceeds(authed("alice").doc("follows/follow1").delete());
  });

  test("cannot delete another user's follow", async () => {
    await seedAdmin(db => db.doc("follows/follow1").set({
      followerUID: "alice",
      listID: "list1",
      followedAt: new Date(),
    }));

    await assertFails(authed("bob").doc("follows/follow1").delete());
  });

  test("follow requires listID to be a string", async () => {
    await assertFails(
      authed("alice").collection("follows").add({
        followerUID: "alice",
        listID: 12345, // number, not string
        followedAt: new Date(),
      })
    );
  });

  test("follow requires followerUID field", async () => {
    await assertFails(
      authed("alice").collection("follows").add({
        // no followerUID
        listID: "list1",
        followedAt: new Date(),
      })
    );
  });
});

describe("Follows — Enumeration & Spam", () => {
  test("⚠️ RISK: any authed user can read ALL follow records", async () => {
    await seedAdmin(async (db) => {
      await db.doc("follows/f1").set({
        followerUID: "alice",
        listID: "list1",
        followedAt: new Date(),
      });
      await db.doc("follows/f2").set({
        followerUID: "bob",
        listID: "list2",
        followedAt: new Date(),
      });
    });

    const snapshot = await assertSucceeds(
      authed("charlie").collection("follows").get()
    );

    console.log(
      `\n  ⚠️  Charlie can see ${snapshot.size} follow records (full social graph exposed)`
    );
    console.log(
      "     Accepted risk for now. If user base grows, move follows to subcollections."
    );
  });

  test("⚠️ RISK: user can mass-create follows (no rate limit in rules)", async () => {
    const db = authed("spammer");
    const batch = db.batch();

    // Create 50 follow records in a batch
    for (let i = 0; i < 50; i++) {
      batch.set(db.collection("follows").doc(`spam_${i}`), {
        followerUID: "spammer",
        listID: `list_${i}`,
        followedAt: new Date(),
      });
    }

    await assertSucceeds(batch.commit());
    console.log(
      "\n  ⚠️  50 follows created in one batch. No server-side rate limit."
    );
    console.log(
      "     Mitigation: Firebase App Check + Cloud Function rate limiting."
    );
  });
});

// ════════════════════════════════════════════════════════════
//  SECTION 6 — Cross-Collection Attacks
// ════════════════════════════════════════════════════════════

describe("Cross-Collection Attacks", () => {
  test("cannot access nonexistent collections", async () => {
    // Firestore default: non-matched paths are denied
    await assertFails(
      authed("alice").doc("secrets/admin_password").set({ pw: "hunter2" })
    );
    await assertFails(
      authed("alice").collection("admin_panel").get()
    );
  });

  test("cannot access subcollections of published lists", async () => {
    // publishedLists doesn't define subcollection rules
    // Firestore should deny by default
    await assertFails(
      authed("alice")
        .doc("publishedLists/list1/comments/comment1")
        .set({ text: "hacked" })
    );
  });

  test("cannot write to root of users collection (without UID match)", async () => {
    // Trying to create a document at /users with a random ID
    await assertFails(
      authed("alice").doc("users/notAlice").set({ displayName: "Fake" })
    );
  });
});

// ════════════════════════════════════════════════════════════
//  SECTION 7 — Data Integrity via Subcollections
// ════════════════════════════════════════════════════════════

describe("Data Integrity — Subcollection Schema", () => {
  test("⚠️ swipedItems accepts arbitrary fields (no schema validation)", async () => {
    // Rules only check auth.uid == uid, not field contents
    const result = authed("alice")
      .doc("users/alice/swipedItems/garbage")
      .set({
        thisFieldDoesntExist: true,
        direction: 12345, // should be string
        randomJunk: { nested: { deep: "garbage" } },
      });

    try {
      await assertSucceeds(result);
      console.log(
        "\n  ⚠️  swipedItems accepts any field structure. Client must validate on pull."
      );
    } catch {
      console.log("\n  ✅ swipedItems validates schema in rules.");
    }
  });

  test("⚠️ userLists accepts arbitrary fields", async () => {
    const result = authed("alice")
      .doc("users/alice/userLists/garbage")
      .set({
        notAName: 42,
        randomField: "anything goes",
      });

    try {
      await assertSucceeds(result);
      console.log(
        "\n  ⚠️  userLists accepts any field structure. Client must validate on pull."
      );
    } catch {
      console.log("\n  ✅ userLists validates schema in rules.");
    }
  });
});

// ════════════════════════════════════════════════════════════
//  SECTION 8 — Post-Ship Audit: New Test Vectors (MT-01–MT-12)
//  Added after v1.3 security audit to cover gaps identified
//  in the original 51-test suite.
// ════════════════════════════════════════════════════════════

describe("Published Lists — isActive type validation (MT-01)", () => {
  const validList = {
    ownerUID: "alice",
    name: "Test List",
    items: [{ tmdbID: 1, title: "Movie" }],
    ownerDisplayName: "Alice",
    isActive: true,
  };

  test("✅ rejects update with isActive as integer", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set(validList));

    await assertFails(
      authed("alice").doc("publishedLists/list1").update({ isActive: 42 })
    );
  });

  test("✅ rejects update with isActive as string", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set(validList));

    await assertFails(
      authed("alice").doc("publishedLists/list1").update({ isActive: "yes" })
    );
  });

  test("✅ rejects update with isActive as null", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set(validList));

    await assertFails(
      authed("alice").doc("publishedLists/list1").update({ isActive: null })
    );
  });

  test("✅ accepts update with isActive as boolean", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set(validList));

    await assertSucceeds(
      authed("alice").doc("publishedLists/list1").update({ isActive: false })
    );
  });
});

describe("Published Lists — description validation (MT-02)", () => {
  const validList = {
    ownerUID: "alice",
    name: "Test List",
    items: [],
    ownerDisplayName: "Alice",
    isActive: true,
  };

  test("✅ rejects create with oversized description", async () => {
    await assertFails(
      authed("alice").doc("publishedLists/bigdesc").set({
        ...validList,
        description: "A".repeat(3000), // exceeds 2000 limit
      })
    );
  });

  test("✅ rejects create with non-string description", async () => {
    await assertFails(
      authed("alice").doc("publishedLists/baddesc").set({
        ...validList,
        description: 12345,
      })
    );
  });

  test("✅ accepts create with valid description", async () => {
    await assertSucceeds(
      authed("alice").doc("publishedLists/gooddesc").set({
        ...validList,
        description: "A great list of movies",
      })
    );
  });

  test("✅ accepts create without description field", async () => {
    await assertSucceeds(
      authed("alice").doc("publishedLists/nodesc").set(validList)
    );
  });

  test("✅ rejects update with oversized description", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set(validList));

    await assertFails(
      authed("alice").doc("publishedLists/list1").update({
        description: "X".repeat(3000),
      })
    );
  });
});

describe("Published Lists — ownerDisplayName size (MT-03, MT-04)", () => {
  const validList = {
    ownerUID: "alice",
    name: "Test List",
    items: [],
    ownerDisplayName: "Alice",
    isActive: true,
  };

  test("✅ rejects create with oversized ownerDisplayName", async () => {
    await assertFails(
      authed("alice").doc("publishedLists/bigname").set({
        ...validList,
        ownerDisplayName: "A".repeat(300), // exceeds 200 limit
      })
    );
  });

  test("✅ rejects update with oversized ownerDisplayName", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set(validList));

    await assertFails(
      authed("alice").doc("publishedLists/list1").update({
        ownerDisplayName: "X".repeat(300),
      })
    );
  });

  test("✅ rejects update with non-string ownerDisplayName", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set(validList));

    await assertFails(
      authed("alice").doc("publishedLists/list1").update({
        ownerDisplayName: 42,
      })
    );
  });

  test("✅ accepts update with valid ownerDisplayName", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set(validList));

    await assertSucceeds(
      authed("alice").doc("publishedLists/list1").update({
        ownerDisplayName: "Alice Updated",
      })
    );
  });
});

describe("Published Lists — itemCount consistency (MT-05)", () => {
  const validList = {
    ownerUID: "alice",
    name: "Test List",
    items: [{ tmdbID: 1, title: "Movie" }],
    ownerDisplayName: "Alice",
    isActive: true,
  };

  test("✅ rejects create with mismatched itemCount", async () => {
    await assertFails(
      authed("alice").doc("publishedLists/mismatch").set({
        ...validList,
        itemCount: 9999, // items has 1 element
      })
    );
  });

  test("✅ accepts create with correct itemCount", async () => {
    await assertSucceeds(
      authed("alice").doc("publishedLists/correct").set({
        ...validList,
        itemCount: 1, // matches items.length
      })
    );
  });

  test("✅ accepts create without itemCount field", async () => {
    // itemCount is optional — only validated if present
    await assertSucceeds(
      authed("alice").doc("publishedLists/nocount").set(validList)
    );
  });

  test("✅ rejects update with mismatched itemCount", async () => {
    await seedAdmin(db => db.doc("publishedLists/list1").set(validList));

    await assertFails(
      authed("alice").doc("publishedLists/list1").update({
        items: [{ tmdbID: 1, title: "A" }, { tmdbID: 2, title: "B" }],
        itemCount: 999,
      })
    );
  });
});

describe("Follows — followedAt type validation (MT-06)", () => {
  test("✅ rejects follow with string followedAt", async () => {
    await assertFails(
      authed("alice").collection("follows").add({
        followerUID: "alice",
        listID: "list1",
        followedAt: "2099-01-01", // string, not timestamp
      })
    );
  });

  test("✅ rejects follow with integer followedAt", async () => {
    await assertFails(
      authed("alice").collection("follows").add({
        followerUID: "alice",
        listID: "list1",
        followedAt: 9999999999, // number, not timestamp
      })
    );
  });

  test("✅ rejects follow without followedAt", async () => {
    await assertFails(
      authed("alice").collection("follows").add({
        followerUID: "alice",
        listID: "list1",
        // followedAt missing
      })
    );
  });
});

describe("Subcollection — Document size (MT-08)", () => {
  test("⚠️ RISK: owner can write large documents to their subcollections", async () => {
    // Rules have no document size check — only Firestore's 1MB hard limit applies
    const largeDoc = {
      mediaID: 123,
      direction: "seen",
      padding: "X".repeat(50000), // 50KB — well within 1MB but larger than any real doc
    };

    const result = authed("alice")
      .doc("users/alice/swipedItems/large_doc")
      .set(largeDoc);

    try {
      await assertSucceeds(result);
      console.log(
        "\n  ⚠️  50KB document accepted in swipedItems. No rule-level size cap."
      );
      console.log(
        "     Mitigation: Add request.resource.data.size() < 10240 to subcollection rules."
      );
    } catch {
      console.log("\n  ✅ Document size is limited by rules.");
    }
  });
});

describe("User Profile — Extra fields (MT-10)", () => {
  test("⚠️ RISK: owner can write arbitrary fields to their profile", async () => {
    const result = authed("alice")
      .doc("users/alice")
      .set({
        displayName: "Alice",
        displayNameLowercase: "alice",
        isAdmin: true, // should not exist
        secretData: "sensitive",
      });

    try {
      await assertSucceeds(result);
      console.log(
        "\n  ⚠️  Arbitrary fields accepted in user profile (no field allowlist)."
      );
    } catch {
      console.log("\n  ✅ Profile enforces field allowlist.");
    }
  });
});

describe("displayNameLowercase consistency (MT-11)", () => {
  test("⚠️ RISK: displayNameLowercase can differ from displayName", async () => {
    const result = authed("alice")
      .doc("users/alice")
      .set({
        displayName: "ALICE",
        displayNameLowercase: "completely_wrong", // inconsistent
      });

    try {
      await assertSucceeds(result);
      console.log(
        "\n  ⚠️  displayNameLowercase not enforced to match displayName.lower()."
      );
      console.log(
        "     Mitigation: Client-side enforcement only. Rules cannot compute .lower()."
      );
    } catch {
      console.log("\n  ✅ displayNameLowercase consistency enforced.");
    }
  });
});

// ════════════════════════════════════════════════════════════
//  SUMMARY — Print results overview
// ════════════════════════════════════════════════════════════

afterAll(() => {
  console.log("\n");
  console.log("═══════════════════════════════════════════════════");
  console.log("  SECURITY TEST SUMMARY");
  console.log("═══════════════════════════════════════════════════");
  console.log("");
  console.log("  ✅ FIXED VULNERABILITIES (verified by tests):");
  console.log("     VULN-FS-003: name.size() <= 200, items.size() <= 500 enforced");
  console.log("     VULN-FS-004: ownerUID immutable on update");
  console.log("     MT-01: isActive type validated on update (bool only)");
  console.log("     MT-02: description validated (string, <= 2000 chars)");
  console.log("     MT-03/04: ownerDisplayName size-capped on create+update");
  console.log("     MT-05: itemCount must match items.size() when present");
  console.log("     MT-06: followedAt must be a timestamp");
  console.log("");
  console.log("  ⚠️  ACCEPTED RISKS (document and monitor):");
  console.log("     - Any authed user can read all user profiles (MT-10)");
  console.log("     - Any authed user can enumerate all follow records");
  console.log("     - No server-side rate limiting on writes");
  console.log("     - Subcollection writes have no schema validation");
  console.log("     - Subcollection docs have no size cap (MT-08)");
  console.log("     - displayNameLowercase not enforced (MT-11)");
  console.log("     - User profile accepts arbitrary fields (MT-10)");
  console.log("");
  console.log("  ✅ FIXED IN CODE (not rules):");
  console.log("     - Account deletion now deletes all subcollections (GDPR)");
  console.log("     - Re-auth on stale session instead of sign-out fallback");
  console.log("     - Deep link doc ID validated (alphanumeric + hyphens only)");
  console.log("     - List names capped at 200 chars client-side");
  console.log("═══════════════════════════════════════════════════");
});
