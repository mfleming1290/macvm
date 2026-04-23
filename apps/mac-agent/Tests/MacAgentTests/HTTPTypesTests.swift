import XCTest
@testable import MacAgent

final class HTTPTypesTests: XCTestCase {
    func testRequestParserSeparatesPathQueryHeadersAndBody() throws {
        let rawRequest = """
        POST /api/sessions/abc/ice?since=4 HTTP/1.1\r
        Host: localhost\r
        Content-Type: application/json\r
        Content-Length: 13\r
        \r
        {"version":1}ignored
        """

        let request = try XCTUnwrap(HTTPRequest(data: Data(rawRequest.utf8)))

        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/sessions/abc/ice")
        XCTAssertEqual(request.query["since"], "4")
        XCTAssertEqual(request.headers["content-type"], "application/json")
        XCTAssertEqual(String(data: request.body, encoding: .utf8), #"{"version":1}"#)
    }

    func testErrorResponsesAreJsonAndCorsCompatible() throws {
        let response = HTTPResponse.error(.permissionMissing)
        let serialized = String(data: response.serialized(), encoding: .utf8)

        XCTAssertEqual(response.statusCode, 403)
        XCTAssertNotNil(serialized)
        XCTAssertTrue(serialized?.contains("Content-Type: application/json") == true)
        XCTAssertTrue(serialized?.contains("Access-Control-Allow-Origin: *") == true)
        XCTAssertTrue(serialized?.contains("Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS") == true)
    }
}
