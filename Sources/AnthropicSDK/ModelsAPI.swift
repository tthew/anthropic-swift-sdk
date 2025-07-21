import Foundation

/// Represents information about a Claude model
public struct ModelInfo: Codable, Equatable {
    /// The model identifier
    public let id: String
    /// The type of object (always "model")
    public let object: String
    /// When the model was created
    public let created: Date
    /// The organization that owns the model
    public let ownedBy: String
    /// The maximum context window size
    public let contextWindow: Int
    /// Whether the model supports vision/images
    public let supportsVision: Bool
    /// Maximum tokens that can be generated
    public let maxTokens: Int
    /// Model description and capabilities
    public let description: String
    
    private enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case ownedBy = "owned_by"
        case contextWindow = "context_window"
        case supportsVision = "supports_vision"
        case maxTokens = "max_tokens"
        case description
    }
    
    public init(id: String, object: String, created: Date, ownedBy: String,
                contextWindow: Int, supportsVision: Bool, maxTokens: Int, description: String) {
        self.id = id
        self.object = object
        self.created = created
        self.ownedBy = ownedBy
        self.contextWindow = contextWindow
        self.supportsVision = supportsVision
        self.maxTokens = maxTokens
        self.description = description
    }
    
    /// Creates model info from a ClaudeModel enum
    /// - Parameter model: The ClaudeModel to convert
    /// - Returns: ModelInfo with the model's capabilities
    public static func from(_ model: ClaudeModel) -> ModelInfo {
        return ModelInfo(
            id: model.rawValue,
            object: "model",
            created: Date(),
            ownedBy: "anthropic",
            contextWindow: model.contextWindow,
            supportsVision: model.supportsVision,
            maxTokens: 4096,
            description: model.description
        )
    }
}

/// Response from the models list endpoint
public struct ModelListResponse: Codable, Equatable {
    /// The type of object (always "list")
    public let object: String
    /// Array of available models
    public let data: [ModelInfo]
    
    public init(object: String, data: [ModelInfo]) {
        self.object = object
        self.data = data
    }
    
    /// Models that support vision/image input
    public var visionCapableModels: [ModelInfo] {
        return data.filter { $0.supportsVision }
    }
    
    /// Models sorted by context window size (largest first)
    public var modelsByContextWindow: [ModelInfo] {
        return data.sorted { $0.contextWindow > $1.contextWindow }
    }
}

/// Resource for managing model operations
public actor ModelsResource {
    private let httpClient: HTTPClient
    private let apiKey: String
    private let baseURL: URL
    
    /// Creates a new models resource
    /// - Parameters:
    ///   - httpClient: The HTTP client to use for requests
    ///   - apiKey: The API key for authentication
    ///   - baseURL: The base URL for the API
    init(httpClient: HTTPClient, apiKey: String, baseURL: URL) {
        self.httpClient = httpClient
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    /// Lists all available models
    /// - Returns: A list of available Claude models with their capabilities
    /// - Throws: HTTPError for network issues or AnthropicError for API errors
    public func list() async throws -> ModelListResponse {
        let url = baseURL.appendingPathComponent("v1/models")
        
        let httpRequest = HTTPRequest(
            url: url,
            method: .GET,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
                "User-Agent": "AnthropicSDK/1.0.0"
            ],
            body: nil
        )
        
        do {
            return try await httpClient.send(httpRequest)
        } catch let httpError as HTTPError {
            // Map specific HTTP status codes to more meaningful errors
            switch httpError {
            case .httpError(let statusCode):
                switch statusCode {
                case 401:
                    throw AnthropicError.invalidAPIKey
                case 429:
                    throw AnthropicError.invalidParameter("Rate limit exceeded")
                case 500...599:
                    throw AnthropicError.invalidParameter("Server error occurred")
                default:
                    throw httpError
                }
            default:
                throw httpError
            }
        }
    }
    
    /// Retrieves information about a specific model
    /// - Parameter model: The Claude model to retrieve information for
    /// - Returns: Detailed information about the specified model
    /// - Throws: HTTPError for network issues or AnthropicError for API errors
    public func retrieve(_ model: ClaudeModel) async throws -> ModelInfo {
        let url = baseURL.appendingPathComponent("v1/models/\(model.rawValue)")
        
        let httpRequest = HTTPRequest(
            url: url,
            method: .GET,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
                "User-Agent": "AnthropicSDK/1.0.0"
            ],
            body: nil
        )
        
        do {
            return try await httpClient.send(httpRequest)
        } catch let httpError as HTTPError {
            // Map specific HTTP status codes to more meaningful errors
            switch httpError {
            case .httpError(let statusCode):
                switch statusCode {
                case 401:
                    throw AnthropicError.invalidAPIKey
                case 404:
                    throw AnthropicError.invalidParameter("Model not found: \(model.rawValue)")
                case 429:
                    throw AnthropicError.invalidParameter("Rate limit exceeded")
                case 500...599:
                    throw AnthropicError.invalidParameter("Server error occurred")
                default:
                    throw httpError
                }
            default:
                throw httpError
            }
        }
    }
    
    /// Gets a list of all available Claude models as ModelInfo objects
    /// - Returns: Array of ModelInfo for all ClaudeModel enum cases
    public func getAllClaudeModels() async -> [ModelInfo] {
        return ClaudeModel.allCases.map { ModelInfo.from($0) }
    }
    
    /// Finds the best model for a given use case
    /// - Parameters:
    ///   - requiresVision: Whether the use case requires vision capabilities
    ///   - preferSpeed: Whether to prefer faster models over more capable ones
    /// - Returns: The recommended Claude model for the use case
    public func recommendModel(requiresVision: Bool = false, preferSpeed: Bool = false) -> ClaudeModel {
        let availableModels = ClaudeModel.allCases
        
        var candidates = availableModels
        
        // Filter by vision requirement
        if requiresVision {
            candidates = candidates.filter { $0.supportsVision }
        }
        
        // Sort by preference
        if preferSpeed {
            // Prefer faster models: Haiku > Sonnet > Opus
            candidates.sort { lhs, rhs in
                let lhsSpeed = getModelSpeed(lhs)
                let rhsSpeed = getModelSpeed(rhs)
                return lhsSpeed > rhsSpeed
            }
        } else {
            // Prefer more capable models: Opus > Sonnet > Haiku
            candidates.sort { lhs, rhs in
                let lhsCapability = getModelCapability(lhs)
                let rhsCapability = getModelCapability(rhs)
                return lhsCapability > rhsCapability
            }
        }
        
        return candidates.first ?? .claude3_5Sonnet
    }
    
    /// Gets a speed score for model ranking (higher = faster)
    private func getModelSpeed(_ model: ClaudeModel) -> Int {
        switch model {
        case .claude3_5Haiku, .claude3Haiku:
            return 3
        case .claude3_5Sonnet, .claude3Sonnet:
            return 2
        case .claude3Opus:
            return 1
        }
    }
    
    /// Gets a capability score for model ranking (higher = more capable)
    private func getModelCapability(_ model: ClaudeModel) -> Int {
        switch model {
        case .claude3Opus:
            return 3
        case .claude3_5Sonnet:
            return 2
        case .claude3Sonnet:
            return 2
        case .claude3_5Haiku:
            return 1
        case .claude3Haiku:
            return 1
        }
    }
}

/// Extension to ClaudeModel to provide descriptions
extension ClaudeModel {
    /// Human-readable description of the model's capabilities
    public var description: String {
        switch self {
        case .claude3_5Sonnet:
            return "Most intelligent model with best performance on complex tasks. Balanced speed and capability."
        case .claude3_5Haiku:
            return "Fast and lightweight model for everyday tasks. Optimized for speed and efficiency."
        case .claude3Opus:
            return "Most powerful model for highly complex tasks requiring deep reasoning and analysis."
        case .claude3Sonnet:
            return "Balanced model with good intelligence and reasonable speed for most use cases."
        case .claude3Haiku:
            return "Fastest model optimized for simple tasks and quick responses."
        }
    }
}