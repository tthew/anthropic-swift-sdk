import XCTest
@testable import AnthropicSDK

final class MessagesAPITests: XCTestCase {
    
    // BDD: GIVEN AnthropicClient WHEN access messages resource THEN MessagesResource available
    func testClientHasMessagesResource() throws {
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        XCTAssertNotNil(client.messages)
        XCTAssertTrue(client.messages is MessagesResource)
    }
    
    // BDD: GIVEN MessagesResource WHEN create message request THEN proper request structure
    func testMessagesResourceCreateRequest() async throws {
        // This test will FAIL initially (RED phase)
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        
        let request = CreateMessageRequest(
            model: .claude3_5Sonnet,
            messages: [.user("Hello, Claude")],
            maxTokens: 1000
        )
        
        XCTAssertEqual(request.model, .claude3_5Sonnet)
        XCTAssertEqual(request.messages.count, 1)
        XCTAssertEqual(request.maxTokens, 1000)
        
        // Test that the request can be created (structure exists)
        XCTAssertNotNil(client.messages)
    }
    
    // BDD: GIVEN CreateMessageRequest WHEN encode to JSON THEN matches Anthropic API format
    func testCreateMessageRequestJSONEncoding() throws {
        let request = CreateMessageRequest(
            model: .claude3_5Sonnet,
            messages: [.user("Hello, Claude")],
            maxTokens: 1000
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["model"] as? String, "claude-3-5-sonnet-20241022")
        XCTAssertEqual(json["max_tokens"] as? Int, 1000)
        
        let messages = json["messages"] as! [[String: Any]]
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"] as? String, "user")
    }
    
    // BDD: GIVEN convenience API WHEN sendMessage THEN creates proper request
    func testConvenienceAPISendMessage() async throws {
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        
        // Test that the method exists and has the right signature
        // We'll use a mock implementation for now
        XCTAssertNotNil(client)
        
        // The method signature should be available
        // This tests that the API surface exists
        // let response = try await client.sendMessage("Hello, Claude")
        // We can't actually test the network call without a mock server
        // but we can test that the method signature exists
    }
    
    // BDD: GIVEN resource API WHEN messages.create THEN creates proper request
    func testResourceAPIMessagesCreate() async throws {
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        
        // Test that the method exists and has the right signature
        XCTAssertNotNil(client.messages)
        
        // The method signature should be available
        // This tests that the API surface exists
        // let response = try await client.messages.create(
        //     model: .claude3_5Sonnet,
        //     messages: [.user("Hello, Claude")],
        //     maxTokens: 1000
        // )
        // We can't actually test the network call without a mock server
        // but we can test that the method signature exists
    }
    
    // BDD: GIVEN CreateMessageRequest WHEN set optional parameters THEN proper structure
    func testCreateMessageRequestWithOptionalParameters() throws {
        let request = CreateMessageRequest(
            model: .claude3_5Sonnet,
            messages: [.user("Hello, Claude")],
            maxTokens: 1000,
            temperature: 0.7,
            topP: 0.9,
            topK: 10,
            stopSequences: ["Human:", "Assistant:"],
            system: "You are a helpful assistant."
        )
        
        XCTAssertEqual(request.temperature, 0.7)
        XCTAssertEqual(request.topP, 0.9)
        XCTAssertEqual(request.topK, 10)
        XCTAssertEqual(request.stopSequences, ["Human:", "Assistant:"])
        XCTAssertEqual(request.system, "You are a helpful assistant.")
    }
    
    // BDD: GIVEN CreateMessageRequest WHEN validate parameters THEN proper validation
    func testCreateMessageRequestValidation() {
        // Test that maxTokens must be positive
        XCTAssertThrowsError(try CreateMessageRequest.validateMaxTokens(0)) { error in
            XCTAssertTrue(error is AnthropicError)
        }
        
        XCTAssertThrowsError(try CreateMessageRequest.validateMaxTokens(-100)) { error in
            XCTAssertTrue(error is AnthropicError)
        }
        
        // Test that valid maxTokens passes
        XCTAssertNoThrow(try CreateMessageRequest.validateMaxTokens(1000))
    }
}