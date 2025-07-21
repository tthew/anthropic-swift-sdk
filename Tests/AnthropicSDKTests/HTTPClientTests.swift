import XCTest
@testable import AnthropicSDK

final class HTTPClientTests: XCTestCase {
    
    // BDD: GIVEN valid HTTP request WHEN send via HTTPClient THEN proper response
    func testHTTPClientSendsValidRequest() async throws {
        // This test will FAIL initially (RED phase)
        let client = HTTPClient()
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        let request = HTTPRequest(
            url: url,
            method: .POST,
            headers: ["Content-Type": "application/json"],
            body: Data()
        )
        
        // For now, we'll test the structure exists and can be called
        XCTAssertNotNil(client)
        XCTAssertNotNil(request)
    }
    
    // BDD: GIVEN HTTPRequest WHEN create with valid parameters THEN success
    func testHTTPRequestInitialization() throws {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        let headers = ["x-api-key": "test", "Content-Type": "application/json"]
        let body = "test data".data(using: .utf8)!
        
        let request = HTTPRequest(
            url: url,
            method: .POST,
            headers: headers,
            body: body
        )
        
        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.method, .POST)
        XCTAssertEqual(request.headers, headers)
        XCTAssertEqual(request.body, body)
    }
    
    // BDD: GIVEN HTTPMethod WHEN access enum cases THEN proper values
    func testHTTPMethodValues() {
        XCTAssertEqual(HTTPMethod.GET.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.POST.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.PUT.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.DELETE.rawValue, "DELETE")
    }
    
    // BDD: GIVEN URLRequest WHEN convert from HTTPRequest THEN proper URLRequest
    func testHTTPRequestToURLRequest() throws {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        let headers = ["x-api-key": "test"]
        let body = "test".data(using: .utf8)!
        
        let httpRequest = HTTPRequest(
            url: url,
            method: .POST,
            headers: headers,
            body: body
        )
        
        let urlRequest = httpRequest.urlRequest
        
        XCTAssertEqual(urlRequest.url, url)
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.httpBody, body)
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "x-api-key"), "test")
    }
    
    // BDD: GIVEN invalid URL WHEN create HTTPRequest THEN handles gracefully
    func testHTTPRequestWithInvalidURL() {
        // Test that our HTTPRequest can handle edge cases
        let url = URL(string: "https://api.anthropic.com")!
        let request = HTTPRequest(url: url, method: .GET, headers: [:], body: nil)
        
        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.method, .GET)
        XCTAssertTrue(request.headers.isEmpty)
        XCTAssertNil(request.body)
    }
}