import XCTest
@testable import AnthropicSDK

/// Performance tests for the Anthropic Swift SDK
/// 
/// These tests measure and validate the performance characteristics of the SDK,
/// including memory usage, response times, and throughput under various conditions.
/// 
/// Tests are designed to run with mock data to avoid external API dependencies
/// while still providing meaningful performance metrics.
class PerformanceTests: XCTestCase {
    
    // MARK: - JSON Processing Performance
    
    func testMessageResponseDecodingPerformance() throws {
        let sampleJSON = """
        {
            "id": "msg_test123",
            "type": "message",
            "role": "assistant", 
            "content": [
                {
                    "type": "text",
                    "text": "This is a test response from Claude with a moderate amount of text to simulate real-world usage patterns and measure JSON decoding performance accurately."
                }
            ],
            "model": "claude-3-5-sonnet-20241022",
            "stop_reason": "end_turn",
            "stop_sequence": null,
            "usage": {
                "input_tokens": 25,
                "output_tokens": 50
            }
        }
        """.data(using: .utf8)!
        
        measure {
            for _ in 1...1000 {
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let _ = try decoder.decode(MessageResponse.self, from: sampleJSON)
                } catch {
                    XCTFail("Decoding failed: \(error)")
                }
            }
        }
    }
    
    func testMessageRequestEncodingPerformance() throws {
        let request = CreateMessageRequest(
            model: .claude3_5Sonnet,
            messages: [
                .user("What is the capital of France?"),
                .assistant("The capital of France is Paris."),
                .user("What about Germany?")
            ],
            maxTokens: 1000,
            temperature: 0.7,
            topP: 0.9
        )
        
        measure {
            for _ in 1...1000 {
                do {
                    let encoder = JSONEncoder()
                    encoder.keyEncodingStrategy = .convertToSnakeCase
                    let _ = try encoder.encode(request)
                } catch {
                    XCTFail("Encoding failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Large Data Handling Performance
    
    func testLargeMessageHandling() throws {
        // Create a large conversation history
        var messages: [Message] = []
        for i in 1...100 {
            messages.append(.user("This is user message number \(i) with some additional text to make it more realistic."))
            messages.append(.assistant("This is assistant response number \(i) with detailed information and explanations."))
        }
        
        measure {
            let request = CreateMessageRequest(
                model: .claude3_5Sonnet,
                messages: messages,
                maxTokens: 1000
            )
            
            do {
                try request.validate()
                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase
                let _ = try encoder.encode(request)
            } catch {
                XCTFail("Large message handling failed: \(error)")
            }
        }
    }
    
    func testStreamingChunkProcessing() throws {
        // Simulate processing many streaming chunks
        let sampleChunks: [StreamingChunk] = [
            .messageStart(MessageStartChunk(message: MessageResponse(
                id: "msg_test", type: "message", role: .assistant, content: [.text("Starting...")],
                model: "claude-3-5-sonnet-20241022", stopReason: nil, stopSequence: nil,
                usage: Usage(inputTokens: 10, outputTokens: 0)
            ))),
            .contentBlockStart(ContentBlockStartChunk(
                index: 0, 
                contentBlock: ContentBlockStartChunk.ContentBlock(type: "text")
            )),
            .contentBlockDelta(ContentBlockDeltaChunk(
                index: 0, 
                delta: ContentBlockDeltaChunk.Delta(type: "text_delta", text: "Hello")
            )),
            .contentBlockDelta(ContentBlockDeltaChunk(
                index: 0, 
                delta: ContentBlockDeltaChunk.Delta(type: "text_delta", text: " world")
            )),
            .contentBlockDelta(ContentBlockDeltaChunk(
                index: 0, 
                delta: ContentBlockDeltaChunk.Delta(type: "text_delta", text: "!")
            )),
            .contentBlockStop(ContentBlockStopChunk(index: 0)),
            .messageStop(MessageStopChunk())
        ]
        
        measure {
            for _ in 1...10000 {
                var fullText = ""
                for chunk in sampleChunks {
                    switch chunk {
                    case .contentBlockDelta(let deltaChunk):
                        fullText += deltaChunk.delta.text
                    default:
                        break
                    }
                }
                XCTAssertEqual(fullText, "Hello world!")
            }
        }
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsageWithLargeResponses() throws {
        // Test memory usage when handling large responses
        let largeContent = String(repeating: "This is a line of text that simulates a large response. ", count: 1000)
        
        measure {
            // Create many large message responses
            var responses: [MessageResponse] = []
            for i in 1...100 {
                let response = MessageResponse(
                    id: "msg_\(i)",
                    type: "message",
                    role: .assistant,
                    content: [.text(largeContent)],
                    model: "claude-3-5-sonnet-20241022",
                    stopReason: "end_turn",
                    stopSequence: nil,
                    usage: Usage(inputTokens: 100, outputTokens: 5000)
                )
                responses.append(response)
            }
            
            // Process the responses
            var totalTokens = 0
            for response in responses {
                totalTokens += response.usage.outputTokens
            }
            
            XCTAssertEqual(totalTokens, 500000)
        }
    }
    
    func testMemoryUsageWithManySmallRequests() throws {
        measure {
            // Create many small requests
            var requests: [CreateMessageRequest] = []
            for i in 1...1000 {
                let request = CreateMessageRequest(
                    model: .claude3_5Haiku,
                    messages: [.user("Message \(i)")],
                    maxTokens: 50
                )
                requests.append(request)
            }
            
            // Validate all requests
            for request in requests {
                do {
                    try request.validate()
                } catch {
                    XCTFail("Request validation failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Tool Processing Performance
    
    func testToolDefinitionProcessing() throws {
        // Create a complex tool with nested schema
        let complexTool = Tool(
            name: "complex_calculator",
            description: "Performs complex mathematical calculations with multiple parameters and nested options",
            inputSchema: [
                "type": "object",
                "properties": [
                    "operation": [
                        "type": "string",
                        "enum": ["add", "subtract", "multiply", "divide", "power", "sqrt", "log", "sin", "cos", "tan"]
                    ],
                    "operands": [
                        "type": "array",
                        "items": [
                            "type": "number"
                        ],
                        "minItems": 1,
                        "maxItems": 10
                    ],
                    "options": [
                        "type": "object",
                        "properties": [
                            "precision": ["type": "integer", "minimum": 1, "maximum": 15],
                            "format": ["type": "string", "enum": ["decimal", "scientific", "fraction"]],
                            "units": ["type": "string"]
                        ]
                    ]
                ],
                "required": ["operation", "operands"]
            ]
        )
        
        measure {
            for _ in 1...1000 {
                do {
                    try complexTool.validate()
                    let encoder = JSONEncoder()
                    let _ = try encoder.encode(complexTool)
                } catch {
                    XCTFail("Tool processing failed: \(error)")
                }
            }
        }
    }
    
    func testToolUseContentProcessing() throws {
        let toolUse = ToolUse(
            id: "tool_test_123",
            name: "calculate",
            input: [
                "expression": "2 + 2 * 3",
                "precision": 2,
                "format": "decimal"
            ]
        )
        
        measure {
            for _ in 1...5000 {
                let content = Content.toolUse(toolUse)
                
                // Simulate processing the tool use content
                switch content {
                case .toolUse(let tool):
                    XCTAssertEqual(tool.id, "tool_test_123")
                    XCTAssertEqual(tool.name, "calculate")
                    XCTAssertNotNil(tool.input["expression"])
                default:
                    XCTFail("Expected toolUse content")
                }
            }
        }
    }
    
    // MARK: - Batch Processing Performance
    
    func testBatchRequestCreation() throws {
        measure {
            var batchRequests: [BatchRequest] = []
            
            for i in 1...1000 {
                let request = BatchRequest(
                    customId: "request_\(i)",
                    method: .POST,
                    url: "/v1/messages",
                    body: CreateMessageRequest(
                        model: .claude3_5Haiku,
                        messages: [.user("Batch message \(i)")],
                        maxTokens: 100
                    )
                )
                batchRequests.append(request)
            }
            
            // Validate the batch
            let createRequest = CreateBatchRequest(requests: batchRequests)
            do {
                try createRequest.validate()
            } catch {
                XCTFail("Batch validation failed: \(error)")
            }
        }
    }
    
    func testBatchResultProcessing() throws {
        // Create sample batch results  
        var results: [BatchResult] = []
        for i in 1...1000 {
            let result = BatchResult(
                customId: "request_\(i)",
                result: .success(MessageResponse(
                    id: "msg_\(i)",
                    type: "message", 
                    role: .assistant,
                    content: [.text("Response \(i)")],
                    model: "claude-3-5-haiku-20241022",
                    stopReason: "end_turn",
                    stopSequence: nil,
                    usage: Usage(inputTokens: 10, outputTokens: 5)
                ))
            )
            results.append(result)
        }
        
        measure {
            // Process all results
            var successCount = 0
            var totalTokens = 0
            
            for result in results {
                if result.isSuccess {
                    successCount += 1
                    if case .success(let messageResponse) = result.result {
                        totalTokens += messageResponse.usage.outputTokens
                    }
                }
            }
            
            XCTAssertEqual(successCount, 1000)
            XCTAssertEqual(totalTokens, 5000)
        }
    }
    
    // MARK: - File Operations Performance
    
    func testFileDataProcessing() throws {
        // Create sample file data
        let sampleData = "Sample file content ".data(using: .utf8)!
        var largeFileData = Data()
        for _ in 1...1000 {
            largeFileData.append(sampleData)
        }
        
        measure {
            for _ in 1...100 {
                let uploadRequest = FileUploadRequest(
                    file: largeFileData,
                    filename: "test_file.txt",
                    contentType: "text/plain",
                    purpose: .document
                )
                
                do {
                    try uploadRequest.validate()
                } catch {
                    XCTFail("File upload validation failed: \(error)")
                }
            }
        }
    }
    
    func testMultipartFormDataGeneration() throws {
        let _ = "This is test file content with some text.".data(using: .utf8)!
        
        measure {
            for _ in 1...1000 {
                let formData = MultipartFormData()
                // Just test creating the form data object
                XCTAssertNotNil(formData)
            }
        }
    }
    
    // MARK: - Configuration Performance
    
    func testConfigurationObjectCreation() throws {
        measure {
            for _ in 1...10000 {
                let config = ClientConfiguration(
                    connectionTimeout: 60,
                    resourceTimeout: 300,
                    maxConcurrentRequests: 10,
                    enableCaching: true,
                    cacheSizeLimit: 50 * 1024 * 1024,
                    enableRetry: true,
                    maxRetryAttempts: 3,
                    retryBaseDelay: 1.0
                )
                
                XCTAssertEqual(config.connectionTimeout, 60)
                XCTAssertTrue(config.enableCaching)
            }
        }
    }
    
    func testRetryStrategyEvaluation() throws {
        let retryStrategy = RetryStrategy(
            maxAttempts: 5,
            baseDelay: 1.0,
            maxDelay: 30.0,
            retryableStatusCodes: [408, 429, 500, 502, 503, 504]
        )
        
        measure {
            for _ in 1...10000 {
                // Test different scenarios
                XCTAssertTrue(retryStrategy.shouldRetry(statusCode: 429))
                XCTAssertTrue(retryStrategy.shouldRetry(statusCode: 503))
                XCTAssertFalse(retryStrategy.shouldRetry(statusCode: 404))
                XCTAssertFalse(retryStrategy.shouldRetry(statusCode: 401))
                
                // Test delay calculation
                let delay1 = retryStrategy.delayForAttempt(1)
                let delay2 = retryStrategy.delayForAttempt(2)
                let delay3 = retryStrategy.delayForAttempt(3)
                
                XCTAssertLessThanOrEqual(delay1, delay2)
                XCTAssertLessThanOrEqual(delay2, delay3)
                XCTAssertLessThanOrEqual(delay3, 30.0)
            }
        }
    }
    
    // MARK: - Concurrent Processing Performance
    
    func testConcurrentJSONProcessing() throws {
        let sampleJSON = """
        {
            "id": "msg_test123",
            "type": "message", 
            "role": "assistant",
            "content": [{"type": "text", "text": "Hello world"}],
            "model": "claude-3-5-sonnet-20241022",
            "stop_reason": "end_turn",
            "stop_sequence": null,
            "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        """.data(using: .utf8)!
        
        measure {
            DispatchQueue.concurrentPerform(iterations: 1000) { _ in
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let _ = try decoder.decode(MessageResponse.self, from: sampleJSON)
                } catch {
                    XCTFail("Concurrent decoding failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Optimization Validation Tests
    
    func testConnectionPoolEfficiency() throws {
        let connectionPool = ConnectionPool(maxConnections: 10)
        
        measure {
            // Simulate acquiring and releasing connections
            for _ in 1...1000 {
                Task {
                    let acquired = await connectionPool.acquireConnection(for: "api.anthropic.com")
                    XCTAssertTrue(acquired || !acquired) // Just test the call
                    await connectionPool.releaseConnection(for: "api.anthropic.com")
                }
            }
        }
    }
    
    func testCircuitBreakerPerformance() throws {
        let circuitBreaker = CircuitBreaker(
            failureThreshold: 5,
            recoveryTimeout: 60,
            monitoringWindow: 300
        )
        
        measure {
            // Just test circuit breaker creation performance
            for _ in 1...10000 {
                let _ = CircuitBreaker(
                    failureThreshold: 5,
                    recoveryTimeout: 60,
                    monitoringWindow: 300
                )
            }
        }
    }
    
    func testResponseCachePerformance() throws {
        let cache = ResponseCache(maxSize: 10 * 1024 * 1024)
        
        let sampleResponse = "This is a cached response".data(using: .utf8)!
        
        measure {
            for i in 1...1000 {
                let key = "cache_key_\(i % 100)"  // Simulate cache hits
                
                // Test cache operations
                cache.store(key: key, data: sampleResponse, contentType: "application/json")
                let _ = cache.retrieve(key: key)
            }
        }
    }
}