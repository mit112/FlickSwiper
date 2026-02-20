import XCTest
import SwiftData
@testable import FlickSwiper

@MainActor
final class SwipedItemStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var store: SwipedItemStore!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([SwipedItem.self, UserList.self, ListEntry.self, FollowedList.self, FollowedListItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        store = SwipedItemStore(context: context)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        store = nil
        try await super.tearDown()
    }

    func testMarkAsSeenPersistsRecord() throws {
        let item = MediaItem(
            id: 100,
            title: "Inception",
            overview: "Dreams within dreams",
            posterPath: "/poster.jpg",
            releaseDate: "2010-07-16",
            rating: 8.8,
            mediaType: .movie
        )

        let saved = try store.markAsSeen(from: item, sourcePlatform: "Netflix")

        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate { $0.swipeDirection == "seen" }
        )
        let stored = try context.fetch(descriptor)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.uniqueID, item.uniqueID)
        XCTAssertEqual(stored.first?.sourcePlatform, "Netflix")
        XCTAssertEqual(saved.uniqueID, item.uniqueID)
    }

    func testSaveToWatchlistPersistsWatchlistDirection() throws {
        let item = MediaItem(
            id: 101,
            title: "Interstellar",
            overview: "Space and time",
            posterPath: nil,
            releaseDate: "2014-11-07",
            rating: 8.7,
            mediaType: .movie
        )

        _ = try store.saveToWatchlist(from: item)

        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate { $0.swipeDirection == "watchlist" }
        )
        let stored = try context.fetch(descriptor)
        XCTAssertEqual(stored.count, 1)
        XCTAssertTrue(stored.first?.isWatchlist == true)
    }

    func testMoveWatchlistToSeenUpdatesDirectionAndDate() throws {
        let item = MediaItem(
            id: 102,
            title: "The Matrix",
            overview: "Reality question",
            posterPath: nil,
            releaseDate: "1999-03-31",
            rating: 8.7,
            mediaType: .movie
        )

        let watchlist = try store.saveToWatchlist(from: item)
        let oldDate = watchlist.dateSwiped
        try store.moveWatchlistToSeen(watchlist)

        XCTAssertEqual(watchlist.swipeDirection, SwipedItem.directionSeen)
        XCTAssertGreaterThanOrEqual(watchlist.dateSwiped, oldDate)
    }

    func testSetPersonalRatingPersistsRating() throws {
        let item = MediaItem(
            id: 103,
            title: "Arrival",
            overview: "Language and time",
            posterPath: nil,
            releaseDate: "2016-11-11",
            rating: 7.9,
            mediaType: .movie
        )

        let saved = try store.markAsSeen(from: item)
        try store.setPersonalRating(5, for: saved)

        let expectedID = item.uniqueID
        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate { $0.uniqueID == expectedID }
        )
        let stored = try context.fetch(descriptor)
        XCTAssertEqual(stored.first?.personalRating, 5)
    }

    func testDuplicateUniqueIDUpsertsInsteadOfDuplicating() throws {
        let item = MediaItem(
            id: 104,
            title: "Duplicated",
            overview: "Duplicate insert test",
            posterPath: nil,
            releaseDate: nil,
            rating: nil,
            mediaType: .movie
        )

        _ = try store.markAsSeen(from: item)
        _ = try store.markAsSeen(from: item)

        // The existence check in markAsSeen should find the existing record and
        // update it rather than inserting a duplicate.
        let expectedID = item.uniqueID
        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate { $0.uniqueID == expectedID }
        )
        let stored = try context.fetch(descriptor)
        XCTAssertEqual(stored.count, 1, "Duplicate insert should update existing, not create a second record")
    }

    // MARK: - Data Preservation Tests

    func testMarkAsSeenPreservesExistingRating() throws {
        let item = MediaItem(
            id: 105,
            title: "Rated Movie",
            overview: "Rating should survive re-mark",
            posterPath: nil,
            releaseDate: "2020-01-01",
            rating: 8.0,
            mediaType: .movie
        )

        let saved = try store.markAsSeen(from: item)
        try store.setPersonalRating(5, for: saved)
        XCTAssertEqual(saved.personalRating, 5)

        // Mark the same item as seen again (simulates re-swipe with "Show Previously Swiped" on)
        let reSaved = try store.markAsSeen(from: item)

        XCTAssertEqual(reSaved.personalRating, 5, "Re-marking as seen must not reset personalRating")
        XCTAssertEqual(reSaved.uniqueID, item.uniqueID)
    }

    func testSaveToWatchlistDoesNotDemoteSeenItemAndPreservesExistingRating() throws {
        let item = MediaItem(
            id: 106,
            title: "Watchlist Preservation",
            overview: "Data should survive direction change",
            posterPath: nil,
            releaseDate: nil,
            rating: 7.5,
            mediaType: .tvShow
        )

        let saved = try store.markAsSeen(from: item)
        try store.setPersonalRating(4, for: saved)

        // Move to watchlist — should update direction but keep rating
        let watchlisted = try store.saveToWatchlist(from: item)

        XCTAssertEqual(watchlisted.personalRating, 4, "Moving to watchlist must not reset personalRating")
        XCTAssertEqual(
            watchlisted.swipeDirection,
            SwipedItem.directionSeen,
            "saveToWatchlist must not demote a seen item"
        )
    }

    func testMovieAndTVShowWithSameIDAreSeparateRecords() throws {
        let movie = MediaItem(
            id: 200,
            title: "Same ID Movie",
            overview: "",
            posterPath: nil,
            releaseDate: nil,
            rating: nil,
            mediaType: .movie
        )
        let tvShow = MediaItem(
            id: 200,
            title: "Same ID TV Show",
            overview: "",
            posterPath: nil,
            releaseDate: nil,
            rating: nil,
            mediaType: .tvShow
        )

        _ = try store.markAsSeen(from: movie)
        _ = try store.markAsSeen(from: tvShow)

        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate { $0.swipeDirection == "seen" }
        )
        let stored = try context.fetch(descriptor)
        XCTAssertEqual(stored.count, 2, "Movie and TV show with same TMDB ID must be separate records")

        let uniqueIDs = Set(stored.map(\.uniqueID))
        XCTAssertTrue(uniqueIDs.contains("movie_200"))
        XCTAssertTrue(uniqueIDs.contains("tvShow_200"))
    }

    // MARK: - Direction Protection in Store

    func testSaveToWatchlistDoesNotDemoteSeenItem() throws {
        let item = MediaItem(
            id: 300,
            title: "Already Seen",
            overview: "Should not be demoted",
            posterPath: nil,
            releaseDate: nil,
            rating: nil,
            mediaType: .movie
        )

        let saved = try store.markAsSeen(from: item)
        try store.setPersonalRating(5, for: saved)

        // Attempt to save the same item to watchlist
        let result = try store.saveToWatchlist(from: item)

        // Must remain "seen" with rating intact
        XCTAssertEqual(result.swipeDirection, SwipedItem.directionSeen,
                       "saveToWatchlist must not demote a seen item")
        XCTAssertEqual(result.personalRating, 5)
    }

    func testSaveToWatchlistAllowsPromotionFromSkipped() throws {
        let item = MediaItem(
            id: 301,
            title: "Skipped Then Watchlisted",
            overview: "",
            posterPath: nil,
            releaseDate: nil,
            rating: nil,
            mediaType: .movie
        )

        // First mark as seen, but we need a skipped item.
        // Create directly:
        let skipped = SwipedItem(from: item, direction: .skipped)
        context.insert(skipped)
        try context.save()

        let result = try store.saveToWatchlist(from: item)
        XCTAssertEqual(result.swipeDirection, SwipedItem.directionWatchlist,
                       "saveToWatchlist should promote a skipped item")
    }

    func testRemoveAlsoAllowsReInsert() throws {
        let item = MediaItem(
            id: 107,
            title: "Removable",
            overview: "",
            posterPath: nil,
            releaseDate: nil,
            rating: nil,
            mediaType: .movie
        )

        let saved = try store.markAsSeen(from: item)
        try store.remove(saved)

        // Should be able to re-add without hitting the existing record path
        let reAdded = try store.markAsSeen(from: item)
        XCTAssertNil(reAdded.personalRating, "Fresh insert after removal should have nil rating")
    }
}
