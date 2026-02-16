import XCTest
@testable import FlickSwiper

// MARK: - GenreMap Tests
//
// Validates the static genre lookup tables used by smart collections.

final class GenreMapTests: XCTestCase {
    
    func testKnownMovieGenreLookup() {
        XCTAssertEqual(GenreMap.name(for: 28), "Action")
        XCTAssertEqual(GenreMap.name(for: 35), "Comedy")
        XCTAssertEqual(GenreMap.name(for: 27), "Horror")
        XCTAssertEqual(GenreMap.name(for: 878), "Sci-Fi")
    }
    
    func testKnownTVGenreLookup() {
        XCTAssertEqual(GenreMap.name(for: 10759), "Action & Adventure")
        XCTAssertEqual(GenreMap.name(for: 10765), "Sci-Fi & Fantasy")
    }
    
    func testFallbackToTVDictionaryWhenMovieMisses() {
        // 10759 only exists in tvGenres — name(for:) checks movie first, then TV
        XCTAssertNotNil(GenreMap.name(for: 10759))
    }
    
    func testUnknownGenreReturnsNil() {
        XCTAssertNil(GenreMap.name(for: 99999))
    }
    
    func testAllGenresHaveIcons() {
        let allKnownIDs = Array(GenreMap.movieGenres.keys) + Array(GenreMap.tvGenres.keys)
        for id in Set(allKnownIDs) {
            let icon = GenreMap.icon(for: id)
            XCTAssertFalse(icon.isEmpty, "Genre ID \(id) should have a non-empty icon")
        }
    }
    
    func testUnknownGenreIconFallsBackToFilm() {
        XCTAssertEqual(GenreMap.icon(for: 99999), "film")
    }
}
