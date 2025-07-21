import XCTest
@testable import AnthropicSDK

final class ToolUseTests: XCTestCase {
    
    // BDD: GIVEN Tool definition WHEN create message with tools THEN proper tool structure
    func testToolDefinitionInMessageRequest() throws {
        // This test will FAIL initially (RED phase)
        let tool = Tool(
            name: "get_weather",
            description: "Get the current weather in a specific location",
            inputSchema: [
                "type": "object",
                "properties": [
                    "location": [
                        "type": "string",
                        "description": "The city and state, e.g. San Francisco, CA"
                    ]
                ],
                "required": ["location"]
            ]
        )
        
        let request = CreateMessageRequest(
            model: .claude3_5Sonnet,
            messages: [.user("What's the weather in San Francisco?")],
            maxTokens: 1000,
            tools: [tool]
        )
        
        XCTAssertEqual(request.tools?.count, 1)
        XCTAssertEqual(request.tools?[0].name, "get_weather")
        XCTAssertEqual(request.tools?[0].description, "Get the current weather in a specific location")
        
        // This will fail because Tool type doesn't exist yet
    }
    
    // BDD: GIVEN message with tool use WHEN decode response THEN proper ToolUse content
    func testToolUseContentInResponse() throws {
        // This test will FAIL initially (RED phase)
        let jsonString = """
        {
            "id": "msg_123",
            "type": "message",
            "role": "assistant",
            "content": [
                {
                    "type": "text",
                    "text": "I'll get the weather for you."
                },
                {
                    "type": "tool_use",
                    "id": "toolu_abc123",
                    "name": "get_weather",
                    "input": {
                        "location": "San Francisco, CA"
                    }
                }
            ],
            "model": "claude-3-5-sonnet-20241022",
            "stop_reason": "tool_use",
            "stop_sequence": null,
            "usage": {
                "input_tokens": 20,
                "output_tokens": 30
            }
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let messageResponse = try decoder.decode(MessageResponse.self, from: data)
        
        XCTAssertEqual(messageResponse.content.count, 2)
        XCTAssertEqual(messageResponse.stopReason, "tool_use")
        
        // Check for tool use content
        if case .toolUse(let toolUse) = messageResponse.content[1] {
            XCTAssertEqual(toolUse.id, "toolu_abc123")
            XCTAssertEqual(toolUse.name, "get_weather")
            XCTAssertNotNil(toolUse.input)
        } else {
            XCTFail("Expected tool_use content")
        }
        
        // This will fail because ToolUse content type doesn't exist yet
    }
    
    // BDD: GIVEN tool result message WHEN create follow-up THEN proper ToolResult content
    func testToolResultContentCreation() throws {
        // This test will FAIL initially (RED phase)
        let toolResult = ToolResult(
            toolUseId: "toolu_abc123",
            content: "The weather in San Francisco, CA is 72°F and sunny."
        )
        
        let message = Message(
            role: .user,
            content: [.toolResult(toolResult)]
        )
        
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content.count, 1)
        
        if case .toolResult(let result) = message.content[0] {
            XCTAssertEqual(result.toolUseId, "toolu_abc123")
            XCTAssertEqual(result.content, "The weather in San Francisco, CA is 72°F and sunny.")
        } else {
            XCTFail("Expected tool_result content")
        }
        
        // This will fail because ToolResult content type doesn't exist yet
    }
    
    // BDD: GIVEN tool use JSON WHEN encode/decode THEN consistent structure
    func testToolUseJSONRoundTrip() throws {
        // This test will FAIL initially (RED phase)
        let toolUse = ToolUse(
            id: "toolu_xyz789",
            name: "calculator",
            input: ["expression": "2 + 2"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(toolUse)
        
        let decoder = JSONDecoder()
        let decodedToolUse = try decoder.decode(ToolUse.self, from: data)
        
        XCTAssertEqual(decodedToolUse.id, "toolu_xyz789")
        XCTAssertEqual(decodedToolUse.name, "calculator")
        XCTAssertEqual(decodedToolUse.input["expression"] as? String, "2 + 2")
        
        // This will fail because ToolUse type doesn't exist yet
    }
    
    // BDD: GIVEN client with tools WHEN send message THEN tool available in request
    func testClientMessageWithTools() async throws {
        // This test will FAIL initially (RED phase)
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        
        let tool = Tool(
            name: "search_web",
            description: "Search the web for information",
            inputSchema: [
                "type": "object",
                "properties": [
                    "query": ["type": "string"]
                ]
            ]
        )
        
        // Test that client supports tool use (API surface test)
        let request = CreateMessageRequest(
            model: .claude3_5Sonnet,
            messages: [.user("Search for Swift programming tutorials")],
            maxTokens: 1000,
            tools: [tool]
        )
        
        XCTAssertNotNil(client.messages)
        XCTAssertEqual(request.tools?.count, 1)
        XCTAssertEqual(request.tools?[0].name, "search_web")
        
        // This will fail because tools parameter doesn't exist in CreateMessageRequest yet
    }
    
    // BDD: GIVEN tool definitions WHEN validate schema THEN proper validation
    func testToolSchemaValidation() throws {
        // This test will FAIL initially (RED phase)
        
        // Valid tool
        let validTool = Tool(
            name: "valid_tool",
            description: "A valid tool",
            inputSchema: ["type": "object"]
        )
        
        XCTAssertNoThrow(try validTool.validate())
        
        // Invalid tool - empty name
        let invalidTool = Tool(
            name: "",
            description: "Invalid tool with empty name",
            inputSchema: ["type": "object"]
        )
        
        XCTAssertThrowsError(try invalidTool.validate()) { error in
            XCTAssertTrue(error is AnthropicError)
        }
        
        // This will fail because Tool.validate() method doesn't exist yet
    }
    
    // BDD: GIVEN client with tool handler WHEN tool execution needed THEN proper callback execution
    func testToolExecutionWorkflow() async throws {
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        
        let weatherTool = Tool(
            name: "get_weather",
            description: "Get weather for a location",
            inputSchema: [
                "type": "object",
                "properties": [
                    "location": ["type": "string"]
                ]
            ]
        )
        
        // Mock tool handler
        let toolHandler: ToolHandler = { name, input in
            XCTAssertEqual(name, "get_weather")
            XCTAssertNotNil(input["location"])
            return "The weather is sunny and 72°F"
        }
        
        // Test that sendMessageWithTools method exists and has the right signature
        XCTAssertNotNil(client.sendMessageWithTools)
        
        // Note: This test validates the API surface but doesn't make network calls
        // to avoid dependencies on external services in unit tests
    }
    
    // BDD: GIVEN ToolUse with parameters WHEN extract parameters THEN Swift-native access patterns
    func testSwiftNativeParameterExtraction() throws {
        let toolUse = ToolUse(
            id: "test_id",
            name: "calculator",
            input: [
                "expression": "2 + 2",
                "precision": 2,
                "scientific": true,
                "result_type": "decimal"
            ]
        )
        
        // Test parameter extraction methods
        XCTAssertEqual(toolUse.stringParameter("expression"), "2 + 2")
        XCTAssertEqual(toolUse.intParameter("precision"), 2)
        XCTAssertEqual(toolUse.boolParameter("scientific"), true)
        XCTAssertEqual(toolUse.stringParameter("result_type"), "decimal")
        
        // Test non-existent parameters
        XCTAssertNil(toolUse.stringParameter("nonexistent"))
        XCTAssertNil(toolUse.intParameter("nonexistent"))
    }
}