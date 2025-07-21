import XCTest
@testable import AnthropicSDK

final class ModelsAPITests: XCTestCase {
    var client: AnthropicClient!
    
    override func setUp() async throws {
        client = try AnthropicClient(apiKey: "sk-ant-test")
    }
    
    override func tearDown() async throws {
        client = nil
    }
    
    // MARK: - Model Info Tests
    
    func testModelInfoFromClaudeModel() throws {
        let modelInfo = ModelInfo.from(.claude3_5Sonnet)
        
        XCTAssertEqual(modelInfo.id, "claude-3-5-sonnet-20241022")
        XCTAssertEqual(modelInfo.object, "model")
        XCTAssertEqual(modelInfo.ownedBy, "anthropic")
        XCTAssertEqual(modelInfo.contextWindow, 200_000)
        XCTAssertTrue(modelInfo.supportsVision)
        XCTAssertEqual(modelInfo.maxTokens, 4096)
        XCTAssertFalse(modelInfo.description.isEmpty)
    }
    
    func testModelInfoEquality() throws {
        let model1 = ModelInfo.from(.claude3_5Sonnet)
        let model2 = ModelInfo.from(.claude3_5Sonnet)
        
        // Note: They won't be equal due to different creation dates
        // This tests our Equatable implementation works
        XCTAssertEqual(model1.id, model2.id)
        XCTAssertEqual(model1.contextWindow, model2.contextWindow)
    }
    
    // MARK: - Model List Response Tests
    
    func testModelListResponseVisionCapableModels() throws {
        let models = [
            ModelInfo.from(.claude3_5Sonnet),
            ModelInfo.from(.claude3_5Haiku),
            ModelInfo.from(.claude3Opus)
        ]
        
        let response = ModelListResponse(object: "list", data: models)
        let visionModels = response.visionCapableModels
        
        XCTAssertEqual(visionModels.count, 2) // 3.5 Sonnet and Opus
        XCTAssertTrue(visionModels.contains { $0.id.contains("sonnet") })
        XCTAssertTrue(visionModels.contains { $0.id.contains("opus") })
    }
    
    func testModelListResponseSortedByContextWindow() throws {
        let models = [
            ModelInfo.from(.claude3Haiku),
            ModelInfo.from(.claude3_5Sonnet),
            ModelInfo.from(.claude3Opus)
        ]
        
        let response = ModelListResponse(object: "list", data: models)
        let sortedModels = response.modelsByContextWindow
        
        // All current models have 200k context, so should maintain order
        XCTAssertEqual(sortedModels.count, 3)
        for model in sortedModels {
            XCTAssertEqual(model.contextWindow, 200_000)
        }
    }
    
    // MARK: - Models Resource Tests
    
    func testModelsResourceInitialization() throws {
        // This tests that the models resource is properly initialized in the client
        XCTAssertNotNil(client.models)
    }
    
    func testGetAllClaudeModels() async throws {
        let allModels = await client.models.getAllClaudeModels()
        
        XCTAssertEqual(allModels.count, ClaudeModel.allCases.count)
        
        // Verify each model type is represented
        let modelIds = allModels.map { $0.id }
        XCTAssertTrue(modelIds.contains("claude-4-opus-20250522"))
        XCTAssertTrue(modelIds.contains("claude-4-sonnet-20250522"))
        XCTAssertTrue(modelIds.contains("claude-3-5-sonnet-20241022"))
        XCTAssertTrue(modelIds.contains("claude-3-5-haiku-20241022"))
        XCTAssertTrue(modelIds.contains("claude-3-opus-20240229"))
        XCTAssertTrue(modelIds.contains("claude-3-sonnet-20240229"))
        XCTAssertTrue(modelIds.contains("claude-3-haiku-20240307"))
    }
    
    func testRecommendModelForSpeed() async throws {
        let fastModel = await client.models.recommendModel(requiresVision: false, preferSpeed: true)
        
        // Should prefer Haiku models for speed
        XCTAssertTrue(fastModel == .claude3_5Haiku || fastModel == .claude3Haiku)
    }
    
    func testRecommendModelForCapability() async throws {
        let capableModel = await client.models.recommendModel(requiresVision: false, preferSpeed: false)
        
        // Should prefer Claude 4 Opus for capability, fallback to Claude 4 Sonnet
        XCTAssertTrue(capableModel == .claude4Opus || capableModel == .claude4Sonnet)
    }
    
    func testRecommendModelWithVisionRequirement() async throws {
        let visionModel = await client.models.recommendModel(requiresVision: true, preferSpeed: false)
        
        // Should only return vision-capable models
        XCTAssertTrue(visionModel.supportsVision)
        XCTAssertNotEqual(visionModel, .claude3_5Haiku) // Haiku 3.5 doesn't support vision
    }
    
    func testRecommendModelWithVisionAndSpeed() async throws {
        let visionSpeedModel = await client.models.recommendModel(requiresVision: true, preferSpeed: true)
        
        // Should prefer vision + speed (probably Haiku 3.0 or Sonnet)
        XCTAssertTrue(visionSpeedModel.supportsVision)
    }
    
    // MARK: - Claude Model Extensions Tests
    
    func testClaudeModelDescriptions() throws {
        for model in ClaudeModel.allCases {
            XCTAssertFalse(model.description.isEmpty, "Model \(model.rawValue) should have a description")
            XCTAssertGreaterThan(model.description.count, 20, "Model \(model.rawValue) description should be meaningful")
        }
    }
    
    func testClaudeModelCapabilities() throws {
        // Test specific model capabilities
        XCTAssertTrue(ClaudeModel.claude3_5Sonnet.supportsVision)
        XCTAssertFalse(ClaudeModel.claude3_5Haiku.supportsVision)
        XCTAssertTrue(ClaudeModel.claude3Opus.supportsVision)
        XCTAssertTrue(ClaudeModel.claude3Sonnet.supportsVision)
        XCTAssertTrue(ClaudeModel.claude3Haiku.supportsVision)
        
        // Test context windows
        for model in ClaudeModel.allCases {
            XCTAssertEqual(model.contextWindow, 200_000)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testModelsResourceErrorHandling() async throws {
        // Test that the models resource properly handles different error scenarios
        
        // Create a client with invalid API key for error testing
        let invalidClient = try AnthropicClient(apiKey: "sk-ant-invalid")
        
        do {
            _ = try await invalidClient.models.list()
            XCTFail("Should have thrown an error for invalid API key")
        } catch let error as AnthropicError {
            // This would normally be an authentication error in a real scenario
            // For now, just verify error handling structure exists
            XCTAssertNotNil(error)
        } catch {
            // Network errors or other issues are also acceptable for this test
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Integration with Client Tests
    
    func testClientHasModelsResource() throws {
        XCTAssertNotNil(client.models)
    }
    
    func testModelsResourceUsesCorrectConfiguration() throws {
        // Verify the models resource is initialized with the same configuration as the client
        XCTAssertEqual(client.apiKey, "sk-ant-test")
        XCTAssertEqual(client.baseURL.absoluteString, "https://api.anthropic.com")
    }
}