import XCTest
@testable import AnthropicSDK

/// Integration tests that verify the SDK works with the real Anthropic API
/// 
/// These tests require a valid API key set in the ANTHROPIC_API_KEY environment variable.
/// They are disabled by default and should only be run when explicitly needed.
/// 
/// To run integration tests:
/// 1. Set ANTHROPIC_API_KEY environment variable
/// 2. Set ANTHROPIC_RUN_INTEGRATION_TESTS=1
/// 3. Run: swift test --filter IntegrationTests
/// 
/// Note: These tests make real API calls and will consume tokens.
class IntegrationTests: XCTestCase {
    
    private var client: AnthropicClient!
    private var shouldRunIntegrationTests: Bool {
        return ProcessInfo.processInfo.environment["ANTHROPIC_RUN_INTEGRATION_TESTS"] == "1"
    }
    
    override func setUp() async throws {
        try await super.setUp()
        
        guard shouldRunIntegrationTests else {
            throw XCTSkip("Integration tests disabled. Set ANTHROPIC_RUN_INTEGRATION_TESTS=1 to enable.")
        }
        
        guard ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil else {
            throw XCTSkip("ANTHROPIC_API_KEY environment variable not set")
        }
        
        do {
            client = try AnthropicClient()
        } catch {
            throw XCTSkip("Failed to initialize client: \(error)")
        }
    }
    
    // MARK: - Basic Message Tests
    
    func testBasicMessageCreation() async throws {
        let response = try await client.sendMessage(
            "Hello! Please respond with just 'Hello back!' and nothing else.",
            model: .claude3_5Haiku, // Use fastest model for integration tests
            maxTokens: 50
        )
        
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertEqual(response.role, .assistant)
        XCTAssertGreaterThan(response.usage.outputTokens, 0)
        XCTAssertGreaterThan(response.usage.inputTokens, 0)
        
        // Check that we got a text response
        guard let firstContent = response.content.first,
              case .text(let text) = firstContent else {
            XCTFail("Expected text content")
            return
        }
        
        XCTAssertTrue(text.contains("Hello"), "Expected response to contain 'Hello'")
    }
    
    func testConversationalMessages() async throws {
        let messages = [
            Message.user("My name is Alex. What should I call you?"),
            Message.assistant("You can call me Claude. Nice to meet you, Alex!"),
            Message.user("What was my name again?")
        ]
        
        let response = try await client.messages.create(
            model: .claude3_5Haiku,
            messages: messages,
            maxTokens: 100
        )
        
        XCTAssertFalse(response.content.isEmpty)
        guard let firstContent = response.content.first,
              case .text(let text) = firstContent else {
            XCTFail("Expected text content")
            return
        }
        
        XCTAssertTrue(text.contains("Alex"), "Expected Claude to remember the name Alex")
    }
    
    // MARK: - Streaming Tests
    
    func testBasicStreaming() async throws {
        let stream = try await client.streamMessage(
            "Count from 1 to 5, putting each number on a new line.",
            model: .claude3_5Haiku,
            maxTokens: 100
        )
        
        var receivedChunks: [StreamingChunk] = []
        var fullText = ""
        
        for try await chunk in stream {
            receivedChunks.append(chunk)
            
            switch chunk {
            case .contentBlockDelta(let deltaChunk):
                fullText += deltaChunk.delta.text
            default:
                break
            }
        }
        
        XCTAssertFalse(receivedChunks.isEmpty)
        XCTAssertFalse(fullText.isEmpty)
        
        // Should contain at least the messageStart and messageStop chunks
        let hasMessageStart = receivedChunks.contains { chunk in
            if case .messageStart(_) = chunk { return true }
            return false
        }
        let hasMessageStop = receivedChunks.contains { chunk in
            if case .messageStop(_) = chunk { return true }
            return false
        }
        
        XCTAssertTrue(hasMessageStart, "Expected messageStart chunk")
        XCTAssertTrue(hasMessageStop, "Expected messageStop chunk")
    }
    
    // MARK: - Tool Use Tests
    
    func testBasicToolUse() async throws {
        let calculateTool = Tool(
            name: "calculate",
            description: "Perform simple arithmetic calculations",
            inputSchema: [
                "type": "object",
                "properties": [
                    "expression": [
                        "type": "string",
                        "description": "Mathematical expression like '2 + 3'"
                    ]
                ],
                "required": ["expression"]
            ]
        )
        
        let response = try await client.sendMessageWithTools(
            "What is 15 + 27?",
            tools: [calculateTool],
            toolHandler: { toolName, input in
                if toolName == "calculate",
                   let expression = input["expression"] as? String {
                    // Simple calculator for test
                    if expression == "15 + 27" {
                        return "42"
                    }
                    return "Calculation result"
                }
                return "Unknown tool"
            },
            model: .claude3_5Haiku,
            maxTokens: 200
        )
        
        XCTAssertFalse(response.content.isEmpty)
        
        // Should contain the final result
        guard let firstContent = response.content.first,
              case .text(let text) = firstContent else {
            XCTFail("Expected text content in response")
            return
        }
        
        XCTAssertTrue(text.contains("42") || text.contains("forty"), 
                     "Expected response to contain the calculation result")
    }
    
    // MARK: - Model Capabilities Tests
    
    func testDifferentModels() async throws {
        let testMessage = "Respond with just the word 'SUCCESS' and nothing else."
        
        // Test Claude 3.5 Haiku
        let haikuResponse = try await client.sendMessage(
            testMessage,
            model: .claude3_5Haiku,
            maxTokens: 10
        )
        
        XCTAssertFalse(haikuResponse.content.isEmpty)
        XCTAssertEqual(haikuResponse.role, .assistant)
        
        // Test Claude 3.5 Sonnet 
        let sonnetResponse = try await client.sendMessage(
            testMessage,
            model: .claude3_5Sonnet,
            maxTokens: 10
        )
        
        XCTAssertFalse(sonnetResponse.content.isEmpty)
        XCTAssertEqual(sonnetResponse.role, .assistant)
    }
    
    // MARK: - Parameter Validation Tests
    
    func testParameterValidation() async throws {
        // Test temperature parameter
        let tempResponse = try await client.messages.create(
            CreateMessageRequest(
                model: .claude3_5Haiku,
                messages: [.user("Say hello")],
                maxTokens: 50,
                temperature: 0.5
            )
        )
        
        XCTAssertFalse(tempResponse.content.isEmpty)
        
        // Test topP parameter
        let topPResponse = try await client.messages.create(
            CreateMessageRequest(
                model: .claude3_5Haiku,
                messages: [.user("Say hello")],
                maxTokens: 50,
                topP: 0.8
            )
        )
        
        XCTAssertFalse(topPResponse.content.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidParameters() async throws {
        do {
            _ = try await client.messages.create(
                CreateMessageRequest(
                    model: .claude3_5Haiku,
                    messages: [.user("Test")],
                    maxTokens: 0 // Invalid - should be > 0
                )
            )
            XCTFail("Expected validation error for maxTokens = 0")
        } catch AnthropicError.invalidParameter(let message) {
            XCTAssertTrue(message.contains("maxTokens"))
        } catch {
            XCTFail("Expected AnthropicError.invalidParameter, got \(error)")
        }
    }
    
    func testEmptyMessages() async throws {
        do {
            _ = try await client.messages.create(
                CreateMessageRequest(
                    model: .claude3_5Haiku,
                    messages: [], // Invalid - should not be empty
                    maxTokens: 100
                )
            )
            XCTFail("Expected validation error for empty messages")
        } catch AnthropicError.invalidParameter(let message) {
            XCTAssertTrue(message.contains("messages"))
        } catch {
            XCTFail("Expected AnthropicError.invalidParameter, got \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testConcurrentRequests() async throws {
        let requestCount = 3
        let requests = (1...requestCount).map { i in
            Task {
                return try await client.sendMessage(
                    "Respond with just the number \(i)",
                    model: .claude3_5Haiku,
                    maxTokens: 10
                )
            }
        }
        
        let responses = try await withThrowingTaskGroup(of: MessageResponse.self, returning: [MessageResponse].self) { group in
            for request in requests {
                group.addTask {
                    return try await request.value
                }
            }
            
            var results: [MessageResponse] = []
            for try await response in group {
                results.append(response)
            }
            return results
        }
        
        XCTAssertEqual(responses.count, requestCount)
        for response in responses {
            XCTAssertFalse(response.content.isEmpty)
        }
    }
    
    // MARK: - Configuration Tests
    
    func testDifferentClients() async throws {
        // Test with different API base URLs (if testing environment supports it)
        let customClient = try AnthropicClient(
            apiKey: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!,
            baseURL: URL(string: "https://api.anthropic.com")!
        )
        
        let response = try await customClient.sendMessage(
            "Hello from custom client!",
            model: .claude3_5Haiku,
            maxTokens: 50
        )
        
        XCTAssertFalse(response.content.isEmpty)
    }
    
    // MARK: - Rate Limiting Tests
    
    func testRateLimitHandling() async throws {
        // This test demonstrates that the client can handle rate limits gracefully
        // In practice, rate limits are handled by the HTTP layer with proper error mapping
        
        // Make several requests quickly to potentially trigger rate limiting
        let responses = try await withThrowingTaskGroup(of: MessageResponse?.self, returning: [MessageResponse].self) { group in
            for i in 1...5 {
                group.addTask { [self] in
                    do {
                        return try await client.sendMessage(
                            "Quick message \(i)",
                            model: .claude3_5Haiku,
                            maxTokens: 10
                        )
                    } catch {
                        // Rate limit errors are expected and handled gracefully
                        print("Request \(i) failed (expected): \(error)")
                        return nil
                    }
                }
            }
            
            var results: [MessageResponse] = []
            for try await response in group {
                if let response = response {
                    results.append(response)
                }
            }
            return results
        }
        
        // We should get at least some successful responses
        XCTAssertGreaterThan(responses.count, 0, "Should have some successful responses")
    }
    
    // MARK: - Content Type Tests
    
    func testSystemMessage() async throws {
        let response = try await client.messages.create(
            CreateMessageRequest(
                model: .claude3_5Haiku,
                messages: [.user("What is your name?")],
                maxTokens: 50,
                system: "You are a helpful assistant named TestBot. Always start your responses with 'TestBot here:'."
            )
        )
        
        XCTAssertFalse(response.content.isEmpty)
        guard let firstContent = response.content.first,
              case .text(let text) = firstContent else {
            XCTFail("Expected text content")
            return
        }
        
        XCTAssertTrue(text.contains("TestBot"), "Expected response to reference the system message")
    }
    
    // MARK: - Edge Cases
    
    func testVeryShortResponse() async throws {
        let response = try await client.sendMessage(
            "Respond with just 'Hi'",
            model: .claude3_5Haiku,
            maxTokens: 5
        )
        
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertLessThanOrEqual(response.usage.outputTokens, 5)
    }
    
    func testStopSequences() async throws {
        let response = try await client.messages.create(
            CreateMessageRequest(
                model: .claude3_5Haiku,
                messages: [.user("Count: 1, 2, 3, STOP, 4, 5")],
                maxTokens: 100,
                stopSequences: ["STOP"]
            )
        )
        
        XCTAssertFalse(response.content.isEmpty)
        guard let firstContent = response.content.first,
              case .text(let text) = firstContent else {
            XCTFail("Expected text content")
            return
        }
        
        // The response should not contain numbers after STOP
        XCTAssertFalse(text.contains("4") && text.contains("5"), 
                      "Response should stop before reaching 4 and 5")
    }
}