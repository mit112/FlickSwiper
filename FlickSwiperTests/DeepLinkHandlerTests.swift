import XCTest
@testable import FlickSwiper

final class DeepLinkHandlerTests: XCTestCase {
    
    // MARK: - Valid Shared List Links
    
    func testValidSharedListLink() {
        let url = URL(string: "https://mit112.github.io/FlickSwiper/list/abc123xyz")!
        let destination = DeepLinkHandler.destination(from: url)
        XCTAssertEqual(destination, .sharedList(docID: "abc123xyz"))
    }
    
    func testSharedListLinkWithLongDocID() {
        let url = URL(string: "https://mit112.github.io/FlickSwiper/list/xK7mN2pQrStUvWxYz0aB")!
        let destination = DeepLinkHandler.destination(from: url)
        XCTAssertEqual(destination, .sharedList(docID: "xK7mN2pQrStUvWxYz0aB"))
    }
    
    // MARK: - Invalid Links
    
    func testWrongHost() {
        let url = URL(string: "https://example.com/FlickSwiper/list/abc123")!
        let destination = DeepLinkHandler.destination(from: url)
        XCTAssertNil(destination)
    }
    
    func testMissingDocID() {
        let url = URL(string: "https://mit112.github.io/FlickSwiper/list/")!
        let destination = DeepLinkHandler.destination(from: url)
        XCTAssertNil(destination)
    }
    
    func testWrongPath() {
        let url = URL(string: "https://mit112.github.io/FlickSwiper/other/abc123")!
        let destination = DeepLinkHandler.destination(from: url)
        XCTAssertNil(destination)
    }
    
    func testRootPath() {
        let url = URL(string: "https://mit112.github.io/FlickSwiper/")!
        let destination = DeepLinkHandler.destination(from: url)
        XCTAssertNil(destination)
    }
    
    func testPrivacyPolicyPath() {
        let url = URL(string: "https://mit112.github.io/FlickSwiper")!
        let destination = DeepLinkHandler.destination(from: url)
        XCTAssertNil(destination)
    }
    
    // MARK: - Constants.DeepLink.listID
    
    func testListIDExtraction() {
        let url = URL(string: "https://mit112.github.io/FlickSwiper/list/testDoc123")!
        let docID = Constants.DeepLink.listID(from: url)
        XCTAssertEqual(docID, "testDoc123")
    }
    
    func testListIDExtractionEmptyPath() {
        let url = URL(string: "https://mit112.github.io/FlickSwiper/list/")!
        let docID = Constants.DeepLink.listID(from: url)
        XCTAssertNil(docID)
    }
    
    func testListIDExtractionWrongPrefix() {
        let url = URL(string: "https://mit112.github.io/other/path/abc")!
        let docID = Constants.DeepLink.listID(from: url)
        XCTAssertNil(docID)
    }
}
