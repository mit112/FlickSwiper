import XCTest
@testable import FlickSwiper

// MARK: - TMDB JSON Decoding Tests
//
// Validates that TMDB API response models decode correctly from JSON,
// including edge cases like missing optional fields and null values.
// These tests use raw JSON strings to simulate real API responses.

final class ModelDecodingTests: XCTestCase {
    
    private let decoder = JSONDecoder()
    
    // MARK: - TMDBMovie
    
    func testMovieDecodesFullResponse() throws {
        let json = """
        {
            "id": 550,
            "title": "Fight Club",
            "overview": "An insomniac office worker and a soap maker form an underground fight club.",
            "poster_path": "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
            "release_date": "1999-10-15",
            "vote_average": 8.433,
            "genre_ids": [18, 53, 35]
        }
        """.data(using: .utf8)!
        
        let movie = try decoder.decode(TMDBMovie.self, from: json)
        
        XCTAssertEqual(movie.id, 550)
        XCTAssertEqual(movie.title, "Fight Club")
        XCTAssertEqual(movie.overview, "An insomniac office worker and a soap maker form an underground fight club.")
        XCTAssertEqual(movie.posterPath, "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg")
        XCTAssertEqual(movie.releaseDate, "1999-10-15")
        XCTAssertEqual(movie.voteAverage, 8.433)
        XCTAssertEqual(movie.genreIds, [18, 53, 35])
    }
    
    func testMovieDecodesWithNullOptionals() throws {
        let json = """
        {
            "id": 999,
            "title": "Unknown Movie",
            "overview": null,
            "poster_path": null,
            "release_date": null,
            "vote_average": null,
            "genre_ids": null
        }
        """.data(using: .utf8)!
        
        let movie = try decoder.decode(TMDBMovie.self, from: json)
        
        XCTAssertEqual(movie.id, 999)
        XCTAssertEqual(movie.title, "Unknown Movie")
        XCTAssertNil(movie.overview)
        XCTAssertNil(movie.posterPath)
        XCTAssertNil(movie.releaseDate)
        XCTAssertNil(movie.voteAverage)
        XCTAssertNil(movie.genreIds)
    }
    
    // MARK: - TMDBTVShow
    
    func testTVShowDecodesFullResponse() throws {
        let json = """
        {
            "id": 1396,
            "name": "Breaking Bad",
            "overview": "A chemistry teacher diagnosed with cancer turns to manufacturing meth.",
            "poster_path": "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
            "first_air_date": "2008-01-20",
            "vote_average": 8.9,
            "genre_ids": [18, 80]
        }
        """.data(using: .utf8)!
        
        let show = try decoder.decode(TMDBTVShow.self, from: json)
        
        XCTAssertEqual(show.id, 1396)
        XCTAssertEqual(show.name, "Breaking Bad")
        XCTAssertEqual(show.posterPath, "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg")
        XCTAssertEqual(show.firstAirDate, "2008-01-20")
        XCTAssertEqual(show.voteAverage, 8.9)
        XCTAssertEqual(show.genreIds, [18, 80])
    }
    
    // MARK: - TMDBTrendingItem
    
    func testTrendingMovieDecodes() throws {
        let json = """
        {
            "id": 550,
            "media_type": "movie",
            "title": "Fight Club",
            "name": null,
            "overview": "An insomniac and a soap maker form a fight club.",
            "poster_path": "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
            "release_date": "1999-10-15",
            "first_air_date": null,
            "vote_average": 8.4,
            "genre_ids": [18]
        }
        """.data(using: .utf8)!
        
        let item = try decoder.decode(TMDBTrendingItem.self, from: json)
        
        XCTAssertEqual(item.mediaType, "movie")
        XCTAssertEqual(item.displayTitle, "Fight Club")
        XCTAssertEqual(item.displayReleaseDate, "1999-10-15")
    }
    
    func testTrendingTVShowDecodes() throws {
        let json = """
        {
            "id": 1396,
            "media_type": "tv",
            "title": null,
            "name": "Breaking Bad",
            "overview": "A chemistry teacher turns to manufacturing meth.",
            "poster_path": "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
            "release_date": null,
            "first_air_date": "2008-01-20",
            "vote_average": 8.9,
            "genre_ids": [18, 80]
        }
        """.data(using: .utf8)!
        
        let item = try decoder.decode(TMDBTrendingItem.self, from: json)
        
        XCTAssertEqual(item.mediaType, "tv")
        XCTAssertEqual(item.displayTitle, "Breaking Bad")
        XCTAssertEqual(item.displayReleaseDate, "2008-01-20")
    }
    
    func testTrendingItemFallsBackToUnknownTitle() throws {
        let json = """
        {
            "id": 1,
            "media_type": "movie",
            "title": null,
            "name": null,
            "overview": null,
            "poster_path": null,
            "release_date": null,
            "first_air_date": null,
            "vote_average": null,
            "genre_ids": null
        }
        """.data(using: .utf8)!
        
        let item = try decoder.decode(TMDBTrendingItem.self, from: json)
        XCTAssertEqual(item.displayTitle, "Unknown")
        XCTAssertNil(item.displayReleaseDate)
    }
    
    // MARK: - TMDBResponse (paginated wrapper)
    
    func testPaginatedResponseDecodes() throws {
        let json = """
        {
            "page": 2,
            "total_pages": 50,
            "total_results": 1000,
            "results": [
                {
                    "id": 550,
                    "title": "Fight Club",
                    "overview": "Test",
                    "poster_path": null,
                    "release_date": "1999-10-15",
                    "vote_average": 8.4,
                    "genre_ids": [18]
                }
            ]
        }
        """.data(using: .utf8)!
        
        let response = try decoder.decode(TMDBResponse<TMDBMovie>.self, from: json)
        
        XCTAssertEqual(response.page, 2)
        XCTAssertEqual(response.totalPages, 50)
        XCTAssertEqual(response.totalResults, 1000)
        XCTAssertEqual(response.results.count, 1)
        XCTAssertEqual(response.results.first?.title, "Fight Club")
    }
    
    func testEmptyResultsPageDecodes() throws {
        let json = """
        {
            "page": 1,
            "total_pages": 0,
            "total_results": 0,
            "results": []
        }
        """.data(using: .utf8)!
        
        let response = try decoder.decode(TMDBResponse<TMDBMovie>.self, from: json)
        
        XCTAssertEqual(response.results.count, 0)
        XCTAssertEqual(response.totalResults, 0)
    }
}
