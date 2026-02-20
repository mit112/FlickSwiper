import XCTest
@testable import FlickSwiper

final class DisplayNameValidatorTests: XCTestCase {
    private var validator: DisplayNameValidator!
    
    override func setUp() {
        super.setUp()
        validator = DisplayNameValidator()
    }
    
    // MARK: - Valid Names
    
    func testValidName() throws {
        let result = try validator.validate("Alex")
        XCTAssertEqual(result, "Alex")
    }
    
    func testMinLengthName() throws {
        let result = try validator.validate("Al")
        XCTAssertEqual(result, "Al")
    }
    
    func testMaxLengthName() throws {
        let name = String(repeating: "A", count: 30)
        let result = try validator.validate(name)
        XCTAssertEqual(result, name)
    }
    
    func testTrimsWhitespace() throws {
        let result = try validator.validate("  Alex  ")
        XCTAssertEqual(result, "Alex")
    }
    
    // MARK: - Invalid: Length
    
    func testEmptyString() {
        XCTAssertThrowsError(try validator.validate("")) { error in
            XCTAssertTrue(error is DisplayNameValidator.ValidationError)
        }
    }
    
    func testOnlyWhitespace() {
        XCTAssertThrowsError(try validator.validate("   ")) { error in
            guard let validationError = error as? DisplayNameValidator.ValidationError else {
                return XCTFail("Expected ValidationError")
            }
            XCTAssertEqual(validationError, .emptyAfterTrimming)
        }
    }
    
    func testTooShort() {
        XCTAssertThrowsError(try validator.validate("A")) { error in
            guard let validationError = error as? DisplayNameValidator.ValidationError else {
                return XCTFail("Expected ValidationError")
            }
            XCTAssertEqual(validationError, .tooShort)
        }
    }
    
    func testTooLong() {
        let name = String(repeating: "A", count: 31)
        XCTAssertThrowsError(try validator.validate(name)) { error in
            guard let validationError = error as? DisplayNameValidator.ValidationError else {
                return XCTFail("Expected ValidationError")
            }
            XCTAssertEqual(validationError, .tooLong)
        }
    }
    
    // MARK: - Invalid: Format
    
    func testContainsNewline() {
        XCTAssertThrowsError(try validator.validate("Alex\nSmith")) { error in
            guard let validationError = error as? DisplayNameValidator.ValidationError else {
                return XCTFail("Expected ValidationError")
            }
            XCTAssertEqual(validationError, .containsNewlines)
        }
    }
    
    // MARK: - Display Name from PersonNameComponents
    
    func testDisplayNameFromComponents() {
        var components = PersonNameComponents()
        components.givenName = "Alex"
        components.familyName = "Smith"
        
        let name = validator.displayName(from: components)
        XCTAssertFalse(name.isEmpty)
        XCTAssertTrue(name.contains("Alex"))
    }
    
    func testDisplayNameFromNilComponents() {
        let name = validator.displayName(from: nil)
        XCTAssertEqual(name, DisplayNameValidator.defaultName)
    }
    
    func testDisplayNameFromEmptyComponents() {
        let components = PersonNameComponents()
        let name = validator.displayName(from: components)
        XCTAssertEqual(name, DisplayNameValidator.defaultName)
    }
    
    // MARK: - Error Descriptions
    
    func testErrorDescriptionsAreNotEmpty() {
        let errors: [DisplayNameValidator.ValidationError] = [
            .tooShort, .tooLong, .containsNewlines, .containsOffensiveTerm, .emptyAfterTrimming
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}
