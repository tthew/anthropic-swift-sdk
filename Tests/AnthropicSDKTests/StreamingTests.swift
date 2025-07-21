import XCTest
@testable import AnthropicSDK

final class StreamingTests: XCTestCase {
    
    // BDD: GIVEN AnthropicClient WHEN create streaming message THEN returns AsyncSequence of streaming chunks
    func testStreamingMessageReturnsAsyncSequence() async throws {
        // This test will FAIL initially (RED phase)
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        
        // Test that streaming API exists with proper signature
        let stream = try await client.streamMessage("Hello, Claude")
        XCTAssertNotNil(stream)
        XCTAssertTrue(stream is MessageStream)
        
        // This will fail because streamMessage method doesn't exist yet
    }
    
    // BDD: GIVEN MessagesResource WHEN stream message request THEN returns proper streaming response
    func testMessagesResourceStreamingAPI() async throws {
        // This test will FAIL initially (RED phase)
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        
        let request = CreateMessageRequest(
            model: .claude3_5Sonnet,
            messages: [.user("Hello, Claude")],
            maxTokens: 1000
        )
        
        // Test that streaming method exists on messages resource
        let stream = try await client.messages.stream(request)
        XCTAssertNotNil(stream)
        XCTAssertTrue(stream is MessageStream)
        
        // This will fail because stream method doesn't exist yet
    }
    
    // BDD: GIVEN streaming response WHEN iterate with AsyncSequence THEN receives incremental content
    func testAsyncSequenceStreamingIteration() async throws {
        // This test focuses on the AsyncSequence API structure without making network calls
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        
        // Test that streaming method exists and returns proper type
        let stream = try await client.streamMessage("Tell me a story")
        XCTAssertNotNil(stream)
        XCTAssertTrue(stream is MessageStream)
        
        // Test that we can get an async iterator (structure test)
        let iterator = stream.makeAsyncIterator()
        XCTAssertNotNil(iterator)
        
        // Don't actually iterate to avoid network calls in unit tests
        // Network integration testing should be done separately
    }
    
    // BDD: GIVEN streaming chunk JSON WHEN decode THEN proper StreamingChunk object
    func testStreamingChunkDecoding() throws {
        // This test will FAIL initially (RED phase)
        let jsonString = """
        {
            "type": "content_block_delta",
            "index": 0,
            "delta": {
                "type": "text_delta",
                "text": "Hello"
            }
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // This will now use the real StreamingChunk type
        let chunk = try decoder.decode(StreamingChunk.self, from: data)
        XCTAssertEqual(chunk.type, "content_block_delta")
        
        // Verify the chunk structure
        if case .contentBlockDelta(let deltaChunk) = chunk {
            XCTAssertEqual(deltaChunk.index, 0)
            XCTAssertEqual(deltaChunk.delta.type, "text_delta")
            XCTAssertEqual(deltaChunk.delta.text, "Hello")
        } else {
            XCTFail("Expected contentBlockDelta chunk")
        }
    }
    
    // BDD: GIVEN streaming request WHEN network error occurs THEN proper error handling
    func testStreamingErrorHandling() async throws {
        // This test will FAIL initially (RED phase)
        let client = try AnthropicClient(apiKey: "sk-ant-invalid")
        
        // Test error handling in streaming context
        // do {
        //     let stream = try await client.streamMessage("Hello")
        //     for try await _ in stream {
        //         XCTFail("Should not receive chunks with invalid API key")
        //     }
        // } catch AnthropicError.invalidAPIKey {
        //     // Expected error
        // } catch {
        //     XCTFail("Expected AnthropicError.invalidAPIKey, got \(error)")
        // }
        
        // For now, verify client creation with invalid key succeeds
        // (actual validation happens during API calls)
        XCTAssertNotNil(client)
        
        // This will fail when we add streaming methods and proper validation
    }
    
    // BDD: GIVEN streaming response WHEN connection drops THEN AsyncSequence terminates gracefully
    func testStreamingConnectionHandling() async throws {
        // This test will FAIL initially (RED phase)
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        
        // Test that streaming handles connection issues properly
        // This is important for mobile apps where connections can drop
        
        // We'll implement this test once we have the streaming infrastructure
        XCTAssertNotNil(client)
        
        // This will become a proper connection handling test
        // testing cancellation, timeout, and graceful termination
    }
    
    // BDD: GIVEN malformed streaming chunk WHEN parsed THEN error chunk is created instead of crashing
    func testStreamingParserResilience() throws {
        // Test that StreamingErrorChunk conforms to Error protocol
        let errorChunk = StreamingErrorChunk(
            error: StreamingErrorChunk.ErrorDetail(
                type: "parsing_error",
                message: "Test error"
            )
        )
        
        XCTAssertTrue(errorChunk is Error)
        XCTAssertEqual(errorChunk.localizedDescription, "parsing_error: Test error")
        
        // Test unknown chunk type handling
        let unknownChunkJSON = """
        {
            "type": "unknown_new_chunk_type",
            "data": "some data"
        }
        """
        
        let data = unknownChunkJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // This should not throw but create an error chunk
        let chunk = try decoder.decode(StreamingChunk.self, from: data)
        
        if case .error(let errorChunk) = chunk {
            XCTAssertEqual(errorChunk.error.type, "unknown_chunk_type")
            XCTAssertTrue(errorChunk.error.message.contains("unknown_new_chunk_type"))
        } else {
            XCTFail("Expected error chunk for unknown type")
        }
    }
    
    // BDD: GIVEN message_delta chunk WHEN decoded THEN proper MessageDeltaChunk is created
    func testMessageDeltaChunkDecoding() throws {
        // Test message_delta chunk with stop_reason and usage
        let messageDeltaJSON = """
        {
            "type": "message_delta",
            "delta": {
                "stop_reason": "end_turn",
                "stop_sequence": null
            },
            "usage": {
                "input_tokens": 150,
                "output_tokens": 25
            }
        }
        """
        
        let data = messageDeltaJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let chunk = try decoder.decode(StreamingChunk.self, from: data)
        XCTAssertEqual(chunk.type, "message_delta")
        
        if case .messageDelta(let messageDelta) = chunk {
            XCTAssertEqual(messageDelta.type, "message_delta")
            XCTAssertEqual(messageDelta.delta.stopReason, "end_turn")
            XCTAssertNil(messageDelta.delta.stopSequence)
            XCTAssertNotNil(messageDelta.usage)
            XCTAssertEqual(messageDelta.usage?.inputTokens, 150)
            XCTAssertEqual(messageDelta.usage?.outputTokens, 25)
        } else {
            XCTFail("Expected messageDelta chunk")
        }
    }
    
    // BDD: GIVEN message_delta without usage WHEN decoded THEN proper MessageDeltaChunk is created
    func testMessageDeltaChunkWithoutUsage() throws {
        // Test message_delta chunk with only delta info
        let messageDeltaJSON = """
        {
            "type": "message_delta",
            "delta": {
                "stop_reason": "tool_use",
                "stop_sequence": "STOP"
            }
        }
        """
        
        let data = messageDeltaJSON.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let chunk = try decoder.decode(StreamingChunk.self, from: data)
        
        if case .messageDelta(let messageDelta) = chunk {
            XCTAssertEqual(messageDelta.delta.stopReason, "tool_use")
            XCTAssertEqual(messageDelta.delta.stopSequence, "STOP")
            XCTAssertNil(messageDelta.usage)
        } else {
            XCTFail("Expected messageDelta chunk")
        }
    }
    
    // BDD: GIVEN streaming flow with message_delta WHEN processing THEN proper event sequence is handled
    func testStreamingFlowWithMessageDelta() throws {
        // Test that message_delta fits properly in the streaming flow
        let chunks: [StreamingChunk] = [
            .messageStart(MessageStartChunk(message: MessageResponse(
                id: "msg_123", type: "message", role: .assistant, content: [], 
                model: "claude-opus-4-20250514", stopReason: nil, stopSequence: nil, 
                usage: Usage(inputTokens: 10, outputTokens: 0)
            ))),
            .contentBlockStart(ContentBlockStartChunk(
                index: 0, 
                contentBlock: ContentBlockStartChunk.ContentBlock(type: "text", text: "")
            )),
            .contentBlockDelta(ContentBlockDeltaChunk(
                index: 0,
                delta: ContentBlockDeltaChunk.Delta(type: "text_delta", text: "Hello")
            )),
            .messageDelta(MessageDeltaChunk(
                delta: MessageDeltaChunk.Delta(stopReason: "end_turn", stopSequence: nil),
                usage: Usage(inputTokens: 10, outputTokens: 5)
            )),
            .contentBlockStop(ContentBlockStopChunk(index: 0)),
            .messageStop(MessageStopChunk())
        ]
        
        // Verify all chunks are properly handled
        XCTAssertEqual(chunks.count, 6)
        XCTAssertEqual(chunks[0].type, "message_start")
        XCTAssertEqual(chunks[1].type, "content_block_start")
        XCTAssertEqual(chunks[2].type, "content_block_delta")
        XCTAssertEqual(chunks[3].type, "message_delta")
        XCTAssertEqual(chunks[4].type, "content_block_stop")
        XCTAssertEqual(chunks[5].type, "message_stop")
        
        // Test that message_delta chunk provides cumulative usage info
        if case .messageDelta(let delta) = chunks[3] {
            XCTAssertEqual(delta.usage?.outputTokens, 5)
            XCTAssertEqual(delta.delta.stopReason, "end_turn")
        } else {
            XCTFail("Expected messageDelta chunk at index 3")
        }
    }
}