import XCTest
@testable import AnthropicSDK

final class ExtendedThinkingTests: XCTestCase {
    
    // BDD: GIVEN CreateMessageRequest with thinking mode WHEN create request THEN includes thinking parameters
    func testMessageRequestWithThinkingMode() throws {
        // This test will FAIL initially (RED phase)
        let request = CreateMessageRequest(
            model: .claude3_5Sonnet,
            messages: [.user("Explain quantum computing")],
            maxTokens: 1000,
            thinkingMode: .extended
        )
        
        XCTAssertEqual(request.thinkingMode, .extended)
        XCTAssertEqual(request.model, .claude3_5Sonnet)
        XCTAssertEqual(request.messages.count, 1)
        
        // This will fail because thinkingMode parameter doesn't exist yet
    }
    
    // BDD: GIVEN ExtendedMessageResponse JSON WHEN decode THEN proper thinking content
    func testExtendedMessageResponseDecoding() throws {
        // This test will FAIL initially (RED phase)
        let jsonString = """
        {
            "id": "msg_123",
            "type": "message",
            "role": "assistant",
            "content": [
                {
                    "type": "text",
                    "text": "Quantum computing uses quantum mechanical phenomena to process information."
                }
            ],
            "model": "claude-3-5-sonnet-20241022",
            "stop_reason": "end_turn",
            "stop_sequence": null,
            "usage": {
                "input_tokens": 15,
                "output_tokens": 25,
                "thinking_tokens": 150
            },
            "thinking": {
                "text": "I need to explain quantum computing clearly, starting with the basic principles...",
                "thinking_tokens": 150,
                "reasoning_score": 0.85,
                "steps": [
                    {
                        "content": "First, I should define what quantum computing is fundamentally",
                        "type": "analysis",
                        "confidence": 0.9,
                        "step_number": 1
                    },
                    {
                        "content": "Then explain the key quantum phenomena: superposition and entanglement",
                        "type": "planning",
                        "confidence": 0.85,
                        "step_number": 2
                    }
                ]
            }
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let response = try decoder.decode(ExtendedMessageResponse.self, from: data)
        
        XCTAssertEqual(response.id, "msg_123")
        XCTAssertEqual(response.role, .assistant)
        XCTAssertEqual(response.content.count, 1)
        XCTAssertEqual(response.usage.thinkingTokens, 150)
        XCTAssertNotNil(response.thinking)
        
        let thinking = try XCTUnwrap(response.thinking)
        XCTAssertTrue(thinking.text.contains("quantum computing"))
        XCTAssertEqual(thinking.thinkingTokens, 150)
        XCTAssertEqual(thinking.reasoningScore, 0.85)
        XCTAssertEqual(thinking.steps?.count, 2)
        
        let firstStep = try XCTUnwrap(thinking.steps?[0])
        XCTAssertEqual(firstStep.type, "analysis")
        XCTAssertEqual(firstStep.confidence, 0.9)
        XCTAssertEqual(firstStep.stepNumber, 1)
        
        // This will fail because ExtendedMessageResponse doesn't exist yet
    }
    
    // BDD: GIVEN ThinkingStep WHEN create with parameters THEN proper initialization
    func testThinkingStepCreation() throws {
        // This test will FAIL initially (RED phase)
        let step = ThinkingStep(
            content: "I need to analyze this problem step by step",
            type: "analysis",
            confidence: 0.85,
            stepNumber: 1
        )
        
        XCTAssertEqual(step.content, "I need to analyze this problem step by step")
        XCTAssertEqual(step.type, "analysis")
        XCTAssertEqual(step.confidence, 0.85)
        XCTAssertEqual(step.stepNumber, 1)
        
        // This will fail because ThinkingStep doesn't exist yet
    }
    
    // BDD: GIVEN ThinkingContent WHEN access reasoning data THEN proper structure
    func testThinkingContentStructure() throws {
        // This test will FAIL initially (RED phase)
        let steps = [
            ThinkingStep(content: "First step", type: "analysis", stepNumber: 1),
            ThinkingStep(content: "Second step", type: "reasoning", stepNumber: 2)
        ]
        
        let thinking = ThinkingContent(
            text: "Let me think about this carefully...",
            steps: steps,
            thinkingTokens: 45,
            reasoningScore: 0.9
        )
        
        XCTAssertEqual(thinking.text, "Let me think about this carefully...")
        XCTAssertEqual(thinking.steps?.count, 2)
        XCTAssertEqual(thinking.thinkingTokens, 45)
        XCTAssertEqual(thinking.reasoningScore, 0.9)
        
        // This will fail because ThinkingContent doesn't exist yet
    }
    
    // BDD: GIVEN ExtendedUsage WHEN calculate totals THEN includes thinking tokens
    func testExtendedUsageCalculation() throws {
        // This test will FAIL initially (RED phase)
        let usage = ExtendedUsage(
            inputTokens: 50,
            outputTokens: 100,
            thinkingTokens: 75,
            cacheTokens: 25
        )
        
        XCTAssertEqual(usage.inputTokens, 50)
        XCTAssertEqual(usage.outputTokens, 100)
        XCTAssertEqual(usage.thinkingTokens, 75)
        XCTAssertEqual(usage.cacheTokens, 25)
        XCTAssertEqual(usage.totalTokens, 250)
        
        // Test without optional tokens
        let basicUsage = ExtendedUsage(inputTokens: 50, outputTokens: 100)
        XCTAssertEqual(basicUsage.totalTokens, 150)
        
        // This will fail because ExtendedUsage doesn't exist yet
    }
    
    // BDD: GIVEN client with extended thinking WHEN send message THEN includes thinking in response
    func testClientWithExtendedThinking() async throws {
        // This test will FAIL initially (RED phase)
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        
        // Test that extended thinking method exists
        let request = CreateMessageRequest(
            model: .claude3_5Sonnet,
            messages: [.user("Solve this complex problem")],
            maxTokens: 1000,
            thinkingMode: .extended
        )
        
        XCTAssertNotNil(client.messages)
        XCTAssertEqual(request.thinkingMode, .extended)
        
        // Test convenience method exists
        XCTAssertNotNil(client.sendMessageWithThinking)
        
        // This will fail because extended thinking methods don't exist yet
    }
    
    // BDD: GIVEN thinking streaming response WHEN iterate chunks THEN receives thinking deltas
    func testThinkingStreamingChunks() throws {
        // This test will FAIL initially (RED phase)
        let thinkingDeltaJson = """
        {
            "type": "thinking_delta",
            "index": 0,
            "delta": {
                "type": "text_delta",
                "text": "I need to consider..."
            }
        }
        """
        
        let data = thinkingDeltaJson.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let chunk = try decoder.decode(ExtendedStreamingChunk.self, from: data)
        
        if case .thinkingDelta(let deltaChunk) = chunk {
            XCTAssertEqual(deltaChunk.type, "thinking_delta")
            XCTAssertEqual(deltaChunk.index, 0)
            XCTAssertEqual(deltaChunk.delta.text, "I need to consider...")
        } else {
            XCTFail("Expected thinking delta chunk")
        }
        
        // This will fail because ExtendedStreamingChunk doesn't exist yet
    }
    
    // BDD: GIVEN ThinkingMode enum WHEN use in request THEN proper encoding
    func testThinkingModeEnum() throws {
        // This test will FAIL initially (RED phase)
        XCTAssertEqual(ThinkingMode.standard.rawValue, "standard")
        XCTAssertEqual(ThinkingMode.extended.rawValue, "extended")
        XCTAssertEqual(ThinkingMode.deep.rawValue, "deep")
        
        // Test all cases exist
        let allModes = ThinkingMode.allCases
        XCTAssertTrue(allModes.contains(.standard))
        XCTAssertTrue(allModes.contains(.extended))
        XCTAssertTrue(allModes.contains(.deep))
        
        // This will fail because ThinkingMode doesn't exist yet
    }
    
    // BDD: GIVEN thinking step JSON WHEN decode/encode THEN consistent structure
    func testThinkingStepJSONRoundTrip() throws {
        // This test will FAIL initially (RED phase)
        let originalStep = ThinkingStep(
            content: "I should analyze the key factors",
            type: "analysis",
            confidence: 0.88,
            stepNumber: 3
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalStep)
        
        let decoder = JSONDecoder()
        let decodedStep = try decoder.decode(ThinkingStep.self, from: data)
        
        XCTAssertEqual(decodedStep.content, "I should analyze the key factors")
        XCTAssertEqual(decodedStep.type, "analysis")
        XCTAssertEqual(decodedStep.confidence, 0.88)
        XCTAssertEqual(decodedStep.stepNumber, 3)
        XCTAssertEqual(originalStep, decodedStep)
        
        // This will fail because ThinkingStep doesn't exist yet
    }
    
    // BDD: GIVEN thinking content with steps WHEN use Swift-native patterns THEN convenient access methods
    func testSwiftNativeThinkingPatterns() throws {
        let analysisStep = ThinkingStep(
            content: "Let me analyze this problem",
            stepType: .analysis,
            confidence: 0.9,
            stepNumber: 1
        )
        
        let reasoningStep = ThinkingStep(
            content: "Based on the analysis, I can reason that...",
            stepType: .reasoning,
            confidence: 0.85,
            stepNumber: 2
        )
        
        let lowConfidenceStep = ThinkingStep(
            content: "I'm not entirely sure about this",
            stepType: .hypothesis,
            confidence: 0.6,
            stepNumber: 3
        )
        
        let thinking = ThinkingContent(
            text: "Full thinking process...",
            steps: [analysisStep, reasoningStep, lowConfidenceStep],
            thinkingTokens: 150,
            reasoningScore: 0.88
        )
        
        // Test step type convenience methods
        XCTAssertEqual(analysisStep.stepType, .analysis)
        XCTAssertEqual(reasoningStep.stepType, .reasoning)
        XCTAssertTrue(analysisStep.isHighConfidence)
        XCTAssertTrue(reasoningStep.isHighConfidence)
        XCTAssertFalse(lowConfidenceStep.isHighConfidence)
        
        // Test thinking content convenience methods
        XCTAssertTrue(thinking.isHighQualityReasoning)
        XCTAssertEqual(thinking.highConfidenceSteps.count, 2)
        XCTAssertEqual(thinking.steps(ofType: .analysis).count, 1)
        XCTAssertEqual(thinking.steps(ofType: .reasoning).count, 1)
        XCTAssertEqual(thinking.steps(ofType: .hypothesis).count, 1)
        
        // Test step type summary
        let summary = thinking.stepTypeSummary
        XCTAssertEqual(summary[.analysis], 1)
        XCTAssertEqual(summary[.reasoning], 1)
        XCTAssertEqual(summary[.hypothesis], 1)
        XCTAssertNil(summary[.planning])
    }
    
    // BDD: GIVEN ExtendedMessageResponse WHEN use convenience methods THEN easy access to data
    func testExtendedResponseConvenienceMethods() throws {
        let usage = ExtendedUsage(inputTokens: 50, outputTokens: 100, thinkingTokens: 75)
        
        let thinking = ThinkingContent(
            text: "Thinking process",
            steps: [],
            thinkingTokens: 75,
            reasoningScore: 0.92
        )
        
        let response = ExtendedMessageResponse(
            id: "msg_123",
            type: "message",
            role: .assistant,
            content: [.text("This is the response text")],
            model: "claude-3-5-sonnet",
            stopReason: "end_turn",
            stopSequence: nil,
            usage: usage,
            thinking: thinking
        )
        
        // Test convenience methods
        XCTAssertTrue(response.hasThinkingData)
        XCTAssertTrue(response.isHighQualityThinking)
        XCTAssertEqual(response.responseText, "This is the response text")
        
        // Test thinking efficiency calculation
        let efficiency = try XCTUnwrap(response.thinkingEfficiency)
        XCTAssertEqual(efficiency, 100.0 / 75.0, accuracy: 0.01) // ~1.33
    }
}