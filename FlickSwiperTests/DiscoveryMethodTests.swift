import XCTest
@testable import FlickSwiper

// MARK: - DiscoveryMethod Tests
//
// Validates streaming provider IDs, icons, logos, and grouped coverage.

final class DiscoveryMethodTests: XCTestCase {
    
    func testStreamingMethodsHaveProviderIDs() {
        let streaming: [DiscoveryMethod] = [
            .netflix, .amazonPrime, .disneyPlus, .max,
            .appleTVPlus, .hulu, .paramountPlus, .peacock,
            .tubi, .plutoTV, .crunchyroll
        ]
        
        for method in streaming {
            XCTAssertNotNil(method.watchProviderID,
                            "\(method.rawValue) should have a watch provider ID")
            XCTAssertTrue(method.isStreamingService)
        }
    }
    
    func testGeneralMethodsHaveNoProviderID() {
        let general: [DiscoveryMethod] = [
            .topRated, .popular, .trending, .nowPlaying, .upcoming
        ]
        
        for method in general {
            XCTAssertNil(method.watchProviderID,
                         "\(method.rawValue) should NOT have a watch provider ID")
            XCTAssertFalse(method.isStreamingService)
        }
    }
    
    func testAllMethodsHaveNonEmptyIcons() {
        for method in DiscoveryMethod.allCases {
            XCTAssertFalse(method.iconName.isEmpty,
                           "\(method.rawValue) should have a non-empty icon name")
        }
    }
    
    func testStreamingMethodsHaveLogoPaths() {
        for method in DiscoveryMethod.allCases where method.isStreamingService {
            XCTAssertNotNil(method.logoPath,
                            "\(method.rawValue) should have a logo path")
            XCTAssertNotNil(method.logoURL,
                            "\(method.rawValue) should have a logo URL")
        }
    }
    
    func testGroupedCoversAllCases() {
        let grouped = DiscoveryMethod.grouped
        let allGroupedMethods = grouped.flatMap(\.methods)
        
        XCTAssertEqual(Set(allGroupedMethods), Set(DiscoveryMethod.allCases),
                       "Grouped methods should cover all cases exactly once")
    }
}
