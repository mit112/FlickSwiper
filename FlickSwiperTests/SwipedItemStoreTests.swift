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
        let schema = Schema([SwipedItem.self, UserList.self, ListEntry.self])
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

        let descriptor = FetchDescriptor<SwipedItem>(
            predicate: #Predicate { $0.uniqueID == item.uniqueID }
        )
        let stored = try context.fetch(descriptor)
        XCTAssertEqual(stored.first?.personalRating, 5)
    }

    func testDuplicateUniqueIDThrowsSaveError() throws {
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
        XCTAssertThrowsError(try store.markAsSeen(from: item))
    }
}
