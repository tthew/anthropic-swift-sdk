import XCTest
@testable import AnthropicSDK

final class MessageTypesTests: XCTestCase {
    
    // BDD: GIVEN valid message with text content WHEN encode to JSON THEN matches Anthropic API format
    func testMessageWithTextContentEncodesToJSON() throws {
        // This test will FAIL initially (RED phase)
        let message = Message(
            role: .user,
            content: [.text("Hello, Claude")]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["role"] as? String, "user")
        
        let content = json["content"] as! [[String: Any]]
        XCTAssertEqual(content.count, 1)
        XCTAssertEqual(content[0]["type"] as? String, "text")
        XCTAssertEqual(content[0]["text"] as? String, "Hello, Claude")
    }
    
    // BDD: GIVEN JSON response from Anthropic WHEN decode to Message THEN all fields properly parsed
    func testJSONResponseDecodesToMessage() throws {
        let jsonString = """
        {
            "id": "msg_123",
            "type": "message",
            "role": "assistant",
            "content": [
                {
                    "type": "text",
                    "text": "Hello! How can I help you today?"
                }
            ],
            "model": "claude-3-5-sonnet-20241022",
            "stop_reason": "end_turn",
            "stop_sequence": null,
            "usage": {
                "input_tokens": 10,
                "output_tokens": 15
            }
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let messageResponse = try decoder.decode(MessageResponse.self, from: data)
        
        XCTAssertEqual(messageResponse.id, "msg_123")
        XCTAssertEqual(messageResponse.type, "message")
        XCTAssertEqual(messageResponse.role, .assistant)
        XCTAssertEqual(messageResponse.content.count, 1)
        
        if case .text(let text) = messageResponse.content[0] {
            XCTAssertEqual(text, "Hello! How can I help you today?")
        } else {
            XCTFail("Expected text content")
        }
        
        XCTAssertEqual(messageResponse.model, "claude-3-5-sonnet-20241022")
        XCTAssertEqual(messageResponse.stopReason, "end_turn")
        XCTAssertNil(messageResponse.stopSequence)
        XCTAssertEqual(messageResponse.usage.inputTokens, 10)
        XCTAssertEqual(messageResponse.usage.outputTokens, 15)
    }
    
    // BDD: GIVEN Message role WHEN access enum cases THEN proper values
    func testMessageRoleValues() {
        XCTAssertEqual(MessageRole.user.rawValue, "user")
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
        XCTAssertEqual(MessageRole.system.rawValue, "system")
    }
    
    // BDD: GIVEN Content types WHEN create different variants THEN proper structure
    func testContentTypeVariants() throws {
        let textContent = Content.text("Hello")
        let imageContent = Content.image(.base64(
            mediaType: "image/jpeg",
            data: "base64data"
        ))
        
        // Test text content
        if case .text(let text) = textContent {
            XCTAssertEqual(text, "Hello")
        } else {
            XCTFail("Expected text content")
        }
        
        // Test image content
        if case .image(let source) = imageContent {
            if case .base64(let mediaType, let data) = source {
                XCTAssertEqual(mediaType, "image/jpeg")
                XCTAssertEqual(data, "base64data")
            } else {
                XCTFail("Expected base64 image source")
            }
        } else {
            XCTFail("Expected image content")
        }
    }
    
    // BDD: GIVEN Claude model WHEN access enum cases THEN proper model identifiers
    func testClaudeModelIdentifiers() {
        XCTAssertEqual(ClaudeModel.claude3_5Sonnet.rawValue, "claude-3-5-sonnet-20241022")
        XCTAssertEqual(ClaudeModel.claude3_5Haiku.rawValue, "claude-3-5-haiku-20241022")
        XCTAssertEqual(ClaudeModel.claude3Opus.rawValue, "claude-3-opus-20240229")
        XCTAssertEqual(ClaudeModel.claude3Sonnet.rawValue, "claude-3-sonnet-20240229")
        XCTAssertEqual(ClaudeModel.claude3Haiku.rawValue, "claude-3-haiku-20240307")
    }
    
    // BDD: GIVEN Usage stats WHEN decode from JSON THEN proper values
    func testUsageStatsDecoding() throws {
        let jsonString = """
        {
            "input_tokens": 100,
            "output_tokens": 50
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let usage = try decoder.decode(Usage.self, from: data)
        
        XCTAssertEqual(usage.inputTokens, 100)
        XCTAssertEqual(usage.outputTokens, 50)
    }
}