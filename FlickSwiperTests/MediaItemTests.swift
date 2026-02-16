import XCTest
@testable import FlickSwiper

// MARK: - MediaItem Tests
//
// Tests MediaItem's conversion initializers (from TMDB models)
// and computed properties (posterURL, thumbnailURL, releaseYear, ratingText).

final class MediaItemTests: XCTestCase {
    
    // MARK: - Conversion from TMDBMovie
    
    func testInitFromMovie() {
        let movie = TMDBMovie(
            id: 550,
            title: "Fight Club",
            overview: "An insomniac office worker...",
            posterPath: "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
            releaseDate: "1999-10-15",
            voteAverage: 8.433,
            genreIds: [18, 53]
        )
        
        let item = MediaItem(from: movie)
        
        XCTAssertEqual(item.id, 550)
        XCTAssertEqual(item.title, "Fight Club")
        XCTAssertEqual(item.overview, "An insomniac office worker...")
        XCTAssertEqual(item.posterPath, "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg")
        XCTAssertEqual(item.mediaType, .movie)
        XCTAssertEqual(item.genreIds, [18, 53])
    }
    
    func testInitFromMovieWithNilOptionals() {
        let movie = TMDBMovie(
            id: 1,
            title: "No Details",
            overview: nil,
            posterPath: nil,
            releaseDate: nil,
            voteAverage: nil,
            genreIds: nil
        )
        
        let item = MediaItem(from: movie)
        
        XCTAssertEqual(item.overview, "")  // nil overview becomes empty string
        XCTAssertNil(item.posterPath)
        XCTAssertNil(item.releaseDate)
        XCTAssertNil(item.rating)
        XCTAssertEqual(item.genreIds, [])  // nil genreIds becomes empty array
    }
    
    // MARK: - Conversion from TMDBTVShow
    
    func testInitFromTVShow() {
        let show = TMDBTVShow(
            id: 1396,
            name: "Breaking Bad",
            overview: "A chemistry teacher...",
            posterPath: "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
            firstAirDate: "2008-01-20",
            voteAverage: 8.9,
            genreIds: [18, 80]
        )
        
        let item = MediaItem(from: show)
        
        XCTAssertEqual(item.id, 1396)
        XCTAssertEqual(item.title, "Breaking Bad")  // name → title
        XCTAssertEqual(item.mediaType, .tvShow)
        XCTAssertEqual(item.releaseDate, "2008-01-20")  // firstAirDate → releaseDate
    }
    
    // MARK: - Conversion from TMDBTrendingItem
    
    func testInitFromTrendingMovie() {
        let trending = TMDBTrendingItem(
            id: 550,
            mediaType: "movie",
            title: "Fight Club",
            name: nil,
            overview: "Test",
            posterPath: "/test.jpg",
            releaseDate: "1999-10-15",
            firstAirDate: nil,
            voteAverage: 8.4,
            genreIds: [18]
        )
        
        let item = MediaItem(from: trending)
        
        XCTAssertEqual(item.mediaType, .movie)
        XCTAssertEqual(item.title, "Fight Club")
        XCTAssertEqual(item.releaseDate, "1999-10-15")
    }
    
    func testInitFromTrendingTVShow() {
        let trending = TMDBTrendingItem(
            id: 1396,
            mediaType: "tv",
            title: nil,
            name: "Breaking Bad",
            overview: "Test",
            posterPath: nil,
            releaseDate: nil,
            firstAirDate: "2008-01-20",
            voteAverage: 8.9,
            genreIds: nil
        )
        
        let item = MediaItem(from: trending)
        
        XCTAssertEqual(item.mediaType, .tvShow)
        XCTAssertEqual(item.title, "Breaking Bad")
        XCTAssertEqual(item.releaseDate, "2008-01-20")
    }
    
    // MARK: - Computed Properties
    
    func testUniqueIDCombinesTypeAndID() {
        let movie = MediaItem(id: 42, title: "T", overview: "", posterPath: nil,
                              releaseDate: nil, rating: nil, mediaType: .movie)
        let show = MediaItem(id: 42, title: "T", overview: "", posterPath: nil,
                             releaseDate: nil, rating: nil, mediaType: .tvShow)
        
        XCTAssertEqual(movie.uniqueID, "movie_42")
        XCTAssertEqual(show.uniqueID, "tvShow_42")
        XCTAssertNotEqual(movie.uniqueID, show.uniqueID,
                          "Same TMDB ID but different media types must produce different uniqueIDs")
    }
    
    func testPosterURLBuildsCorrectly() {
        let item = MediaItem(id: 1, title: "T", overview: "", posterPath: "/abc.jpg",
                             releaseDate: nil, rating: nil, mediaType: .movie)
        
        XCTAssertEqual(item.posterURL?.absoluteString, "https://image.tmdb.org/t/p/w500/abc.jpg")
    }
    
    func testPosterURLIsNilWhenPathIsNil() {
        let item = MediaItem(id: 1, title: "T", overview: "", posterPath: nil,
                             releaseDate: nil, rating: nil, mediaType: .movie)
        
        XCTAssertNil(item.posterURL)
    }
    
    func testThumbnailURLUsesW185() {
        let item = MediaItem(id: 1, title: "T", overview: "", posterPath: "/abc.jpg",
                             releaseDate: nil, rating: nil, mediaType: .movie)
        
        XCTAssertEqual(item.thumbnailURL?.absoluteString, "https://image.tmdb.org/t/p/w185/abc.jpg")
    }
    
    func testReleaseYearExtractsFirstFourChars() {
        let item = MediaItem(id: 1, title: "T", overview: "", posterPath: nil,
                             releaseDate: "2024-07-15", rating: nil, mediaType: .movie)
        
        XCTAssertEqual(item.releaseYear, "2024")
    }
    
    func testReleaseYearIsNilForEmptyDate() {
        let item = MediaItem(id: 1, title: "T", overview: "", posterPath: nil,
                             releaseDate: "", rating: nil, mediaType: .movie)
        
        XCTAssertNil(item.releaseYear)
    }
    
    func testReleaseYearIsNilForNilDate() {
        let item = MediaItem(id: 1, title: "T", overview: "", posterPath: nil,
                             releaseDate: nil, rating: nil, mediaType: .movie)
        
        XCTAssertNil(item.releaseYear)
    }
    
    func testRatingTextFormatsToOneDecimal() {
        let item = MediaItem(id: 1, title: "T", overview: "", posterPath: nil,
                             releaseDate: nil, rating: 8.433, mediaType: .movie)
        
        XCTAssertEqual(item.ratingText, "8.4")
    }
    
    func testRatingTextIsNilForZero() {
        let item = MediaItem(id: 1, title: "T", overview: "", posterPath: nil,
                             releaseDate: nil, rating: 0.0, mediaType: .movie)
        
        XCTAssertNil(item.ratingText)
    }
    
    func testRatingTextIsNilForNilRating() {
        let item = MediaItem(id: 1, title: "T", overview: "", posterPath: nil,
                             releaseDate: nil, rating: nil, mediaType: .movie)
        
        XCTAssertNil(item.ratingText)
    }
    
    // MARK: - Hashable / Identifiable
    
    func testMediaItemHashableByID() {
        let a = MediaItem(id: 1, title: "A", overview: "", posterPath: nil,
                          releaseDate: nil, rating: nil, mediaType: .movie)
        let b = MediaItem(id: 1, title: "B", overview: "Different", posterPath: nil,
                          releaseDate: nil, rating: nil, mediaType: .movie)
        
        // Custom Hashable uses (id, mediaType) — same combo means same identity
        let set: Set<MediaItem> = [a, b]
        XCTAssertEqual(set.count, 1,
                       "Same id + mediaType should deduplicate in a Set")
    }
}
