import XCTest
@testable import AnthropicSDK

final class ClientInitializationTests: XCTestCase {
    
    // BDD: GIVEN valid API key WHEN create client THEN success
    func testClientInitializationWithValidAPIKey() throws {
        // This test will FAIL initially (RED phase)
        let client = try AnthropicClient(apiKey: "sk-ant-valid-key")
        XCTAssertNotNil(client)
        XCTAssertEqual(client.apiKey, "sk-ant-valid-key")
    }
    
    // BDD: GIVEN invalid API key WHEN create client THEN error
    func testClientInitializationWithInvalidAPIKey() {
        // This test will FAIL initially (RED phase)
        XCTAssertThrowsError(try AnthropicClient(apiKey: "invalid-key")) { error in
            XCTAssertTrue(error is AnthropicError)
            if case .invalidAPIKey = error as? AnthropicError {
                // Expected error type
            } else {
                XCTFail("Expected invalidAPIKey error")
            }
        }
    }
    
    // BDD: GIVEN empty API key WHEN create client THEN error  
    func testClientInitializationWithEmptyAPIKey() {
        XCTAssertThrowsError(try AnthropicClient(apiKey: "")) { error in
            XCTAssertTrue(error is AnthropicError)
            if case .emptyAPIKey = error as? AnthropicError {
                // Expected error type
            } else {
                XCTFail("Expected emptyAPIKey error")
            }
        }
    }
    
    // BDD: GIVEN environment variable WHEN no explicit key THEN use env
    func testClientInitializationFromEnvironment() throws {
        // Set environment variable for test
        setenv("ANTHROPIC_API_KEY", "sk-ant-env-key", 1)
        
        let client = try AnthropicClient() // Should use env variable
        XCTAssertEqual(client.apiKey, "sk-ant-env-key")
        
        // Cleanup
        unsetenv("ANTHROPIC_API_KEY")
    }
    
    // BDD: GIVEN no env variable WHEN no explicit key THEN error
    func testClientInitializationFromEnvironmentWithoutKey() {
        // Ensure no environment variable is set
        unsetenv("ANTHROPIC_API_KEY")
        
        XCTAssertThrowsError(try AnthropicClient()) { error in
            XCTAssertTrue(error is AnthropicError)
        }
    }
}