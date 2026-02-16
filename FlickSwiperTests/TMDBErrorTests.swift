import XCTest
@testable import FlickSwiper

// MARK: - TMDBError Tests
//
// Validates that every TMDBError case produces a non-nil, user-friendly
// error description. These strings are displayed directly in the UI.

final class TMDBErrorTests: XCTestCase {
    
    func testAllErrorCasesHaveDescriptions() {
        let cases: [TMDBError] = [
            .invalidURL,
            .invalidResponse,
            .rateLimited,
            .httpError(statusCode: 500),
            .decodingError(NSError(domain: "test", code: 0)),
            .noAPIKey
        ]
        
        for error in cases {
            XCTAssertNotNil(error.errorDescription,
                            "\(error) should have a non-nil errorDescription")
            XCTAssertFalse(error.errorDescription!.isEmpty,
                           "\(error) should have a non-empty errorDescription")
        }
    }
    
    func testHttpErrorIncludesStatusCode() {
        let error = TMDBError.httpError(statusCode: 404)
        XCTAssertTrue(error.errorDescription!.contains("404"))
    }
    
    func testNoAPIKeyErrorIsUserFacing() {
        let error = TMDBError.noAPIKey
        // Should NOT contain developer jargon like "API key" — user-facing message
        XCTAssertFalse(error.errorDescription!.contains("API key"),
                       "noAPIKey error should use user-friendly language, not developer jargon")
    }
}
