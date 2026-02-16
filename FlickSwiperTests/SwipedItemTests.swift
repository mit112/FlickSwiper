import XCTest
import SwiftData
@testable import FlickSwiper

// MARK: - SwipedItem Tests
//
// Tests SwipedItem's computed properties and initialization logic.
// SwipedItem is a SwiftData @Model but its computed properties can be
// tested without a persistent context.

final class SwipedItemTests: XCTestCase {
    
    // MARK: - Initialization
    
    func testInitFromMediaItem() {
        let media = MediaItem(
            id: 550,
            title: "Fight Club",
            overview: "An insomniac...",
            posterPath: "/test.jpg",
            releaseDate: "1999-10-15",
            rating: 8.4,
            mediaType: .movie,
            genreIds: [18, 53, 35]
        )
        
        let swiped = SwipedItem(from: media, direction: .seen)
        
        XCTAssertEqual(swiped.uniqueID, "movie_550")
        XCTAssertEqual(swiped.mediaID, 550)
        XCTAssertEqual(swiped.title, "Fight Club")
        XCTAssertEqual(swiped.swipeDirection, "seen")
        XCTAssertEqual(swiped.genreIDsString, "18,53,35")
        XCTAssertNil(swiped.personalRating)
        XCTAssertNil(swiped.sourcePlatform)
    }
    
    func testInitFromMediaItemWatchlist() {
        let media = MediaItem(
            id: 42, title: "T", overview: "", posterPath: nil,
            releaseDate: nil, rating: nil, mediaType: .tvShow
        )
        
        let swiped = SwipedItem(from: media, direction: .watchlist)
        
        XCTAssertEqual(swiped.uniqueID, "tvShow_42")
        XCTAssertEqual(swiped.swipeDirection, "watchlist")
    }
    
    // MARK: - isSeen / isWatchlist
    
    func testIsSeenReturnsTrueForSeenDirection() {
        let swiped = makeSwipedItem(direction: .seen)
        XCTAssertTrue(swiped.isSeen)
        XCTAssertFalse(swiped.isWatchlist)
    }
    
    func testIsWatchlistReturnsTrueForWatchlistDirection() {
        let swiped = makeSwipedItem(direction: .watchlist)
        XCTAssertTrue(swiped.isWatchlist)
        XCTAssertFalse(swiped.isSeen)
    }
    
    func testSkippedIsNeitherSeenNorWatchlist() {
        let swiped = makeSwipedItem(direction: .skipped)
        XCTAssertFalse(swiped.isSeen)
        XCTAssertFalse(swiped.isWatchlist)
    }
    
    // MARK: - Genre ID Parsing
    
    func testGenreIDsParsesCommaSeparatedString() {
        let swiped = makeSwipedItem(direction: .seen)
        swiped.genreIDsString = "28,12,878"
        
        XCTAssertEqual(swiped.genreIDs, [28, 12, 878])
    }
    
    func testGenreIDsReturnsEmptyForNilString() {
        let swiped = makeSwipedItem(direction: .seen)
        swiped.genreIDsString = nil
        
        XCTAssertEqual(swiped.genreIDs, [])
    }
    
    func testGenreIDsReturnsEmptyForEmptyString() {
        let swiped = makeSwipedItem(direction: .seen)
        swiped.genreIDsString = ""
        
        XCTAssertEqual(swiped.genreIDs, [])
    }
    
    func testGenreIDsSkipsNonNumericValues() {
        let swiped = makeSwipedItem(direction: .seen)
        swiped.genreIDsString = "28,abc,878"
        
        XCTAssertEqual(swiped.genreIDs, [28, 878])
    }
    
    // MARK: - Release Year
    
    func testReleaseYearExtractsYear() {
        let swiped = makeSwipedItem(direction: .seen)
        swiped.releaseDate = "2024-07-15"
        
        XCTAssertEqual(swiped.releaseYear, "2024")
    }
    
    func testReleaseYearNilForEmptyString() {
        let swiped = makeSwipedItem(direction: .seen)
        swiped.releaseDate = ""
        
        XCTAssertNil(swiped.releaseYear)
    }
    
    func testReleaseYearNilForNilDate() {
        let swiped = makeSwipedItem(direction: .seen)
        swiped.releaseDate = nil
        
        XCTAssertNil(swiped.releaseYear)
    }
    
    // MARK: - Rating Text
    
    func testRatingTextFormatsCorrectly() {
        let swiped = makeSwipedItem(direction: .seen)
        swiped.rating = 7.856
        
        XCTAssertEqual(swiped.ratingText, "7.9")
    }
    
    func testRatingTextNilForZero() {
        let swiped = makeSwipedItem(direction: .seen)
        swiped.rating = 0.0
        
        XCTAssertNil(swiped.ratingText)
    }
    
    // MARK: - Poster URLs
    
    func testPosterURLUsesW500() {
        let swiped = makeSwipedItem(direction: .seen)
        swiped.posterPath = "/abc.jpg"
        
        XCTAssertEqual(swiped.posterURL?.absoluteString, "https://image.tmdb.org/t/p/w500/abc.jpg")
    }
    
    func testThumbnailURLUsesW185() {
        let swiped = makeSwipedItem(direction: .seen)
        swiped.posterPath = "/abc.jpg"
        
        XCTAssertEqual(swiped.thumbnailURL?.absoluteString, "https://image.tmdb.org/t/p/w185/abc.jpg")
    }
    
    func testPosterURLsNilWhenPathIsNil() {
        let swiped = makeSwipedItem(direction: .seen)
        swiped.posterPath = nil
        
        XCTAssertNil(swiped.posterURL)
        XCTAssertNil(swiped.thumbnailURL)
    }
    
    // MARK: - Media Type Enum
    
    func testMediaTypeEnumParsesMovie() {
        let swiped = makeSwipedItem(direction: .seen)
        // mediaType is set to "movie" by default in helper
        XCTAssertEqual(swiped.mediaTypeEnum, .movie)
    }
    
    func testMediaTypeEnumDefaultsToMovieForUnknown() {
        let swiped = makeSwipedItem(direction: .seen)
        swiped.mediaType = "unknown_type"
        
        XCTAssertEqual(swiped.mediaTypeEnum, .movie,
                       "Unknown media type should default to .movie")
    }
    
    // MARK: - Personal Rating
    
    func testPersonalRatingDefaultsToNil() {
        let swiped = makeSwipedItem(direction: .seen)
        XCTAssertNil(swiped.personalRating)
    }
    
    func testPersonalRatingCanBeSet() {
        let swiped = makeSwipedItem(direction: .seen)
        swiped.personalRating = 4
        XCTAssertEqual(swiped.personalRating, 4)
    }
    
    // MARK: - Helpers
    
    private func makeSwipedItem(direction: SwipedItem.SwipeDirection) -> SwipedItem {
        SwipedItem(
            mediaID: 1,
            mediaType: .movie,
            swipeDirection: direction,
            title: "Test",
            overview: "Overview",
            posterPath: nil,
            releaseDate: nil,
            rating: nil
        )
    }
}
