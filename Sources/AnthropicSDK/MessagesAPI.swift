import Foundation

/// Request structure for creating messages with the Anthropic API
public struct CreateMessageRequest: Codable, Equatable {
    /// The Claude model to use for generating the response
    public let model: ClaudeModel
    /// The conversation messages (user, assistant, system)
    public let messages: [Message]
    /// Maximum number of tokens to generate in the response (1-4096)
    public let maxTokens: Int
    /// Controls randomness in response generation (0.0 = deterministic, 1.0 = maximum randomness)
    public let temperature: Double?
    /// Controls diversity via nucleus sampling (0.0-1.0)
    public let topP: Double?
    /// Controls diversity by limiting to top K tokens (1-40)
    public let topK: Int?
    /// Sequences that will cause the model to stop generating
    public let stopSequences: [String]?
    /// System message to set the assistant's behavior and context
    public let system: String?
    /// Tools available for the assistant to use
    public let tools: [Tool]?
    /// How the assistant should choose tools
    public let toolChoice: ToolChoice?
    /// Extended thinking mode for accessing reasoning steps
    public let thinkingMode: ThinkingMode?
    /// File references for document analysis
    public let files: [FileReference]?
    
    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case stopSequences = "stop_sequences"
        case system
        case tools
        case toolChoice = "tool_choice"
        case thinkingMode = "thinking_mode"
        case files
    }
    
    /// Creates a new message creation request
    /// - Parameters:
    ///   - model: The Claude model to use
    ///   - messages: The conversation messages
    ///   - maxTokens: Maximum tokens to generate
    ///   - temperature: Temperature for response randomness (optional)
    ///   - topP: Top-p sampling parameter (optional)
    ///   - topK: Top-k sampling parameter (optional)
    ///   - stopSequences: Sequences where the API will stop generating (optional)
    ///   - system: System message to set context (optional)
    ///   - tools: Tools available for the assistant to use (optional)
    ///   - toolChoice: How the assistant should choose tools (optional)
    ///   - thinkingMode: Extended thinking mode for reasoning access (optional)
    ///   - files: File references for document analysis (optional)
    public init(model: ClaudeModel, messages: [Message], maxTokens: Int, 
                temperature: Double? = nil, topP: Double? = nil, topK: Int? = nil,
                stopSequences: [String]? = nil, system: String? = nil,
                tools: [Tool]? = nil, toolChoice: ToolChoice? = nil,
                thinkingMode: ThinkingMode? = nil, files: [FileReference]? = nil) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.stopSequences = stopSequences
        self.system = system
        self.tools = tools
        self.toolChoice = toolChoice
        self.thinkingMode = thinkingMode
        self.files = files
    }
    
    /// Validates the maxTokens parameter
    /// - Parameter maxTokens: The maximum tokens value to validate
    /// - Throws: AnthropicError if validation fails
    public static func validateMaxTokens(_ maxTokens: Int) throws {
        guard maxTokens > 0 else {
            throw AnthropicError.invalidParameter("maxTokens must be greater than 0")
        }
        
        guard maxTokens <= 4096 else {
            throw AnthropicError.invalidParameter("maxTokens cannot exceed 4096")
        }
    }
    
    /// Validates temperature parameter
    /// - Parameter temperature: The temperature value to validate
    /// - Throws: AnthropicError if validation fails
    public static func validateTemperature(_ temperature: Double?) throws {
        guard let temp = temperature else { return }
        
        guard temp >= 0.0 && temp <= 1.0 else {
            throw AnthropicError.invalidParameter("temperature must be between 0.0 and 1.0")
        }
    }
    
    /// Validates topP parameter
    /// - Parameter topP: The topP value to validate
    /// - Throws: AnthropicError if validation fails
    public static func validateTopP(_ topP: Double?) throws {
        guard let value = topP else { return }
        
        guard value >= 0.0 && value <= 1.0 else {
            throw AnthropicError.invalidParameter("topP must be between 0.0 and 1.0")
        }
    }
    
    /// Validates topK parameter
    /// - Parameter topK: The topK value to validate
    /// - Throws: AnthropicError if validation fails
    public static func validateTopK(_ topK: Int?) throws {
        guard let value = topK else { return }
        
        guard value >= 1 && value <= 40 else {
            throw AnthropicError.invalidParameter("topK must be between 1 and 40")
        }
    }
    
    /// Validates all parameters of the request
    /// - Throws: AnthropicError if any validation fails
    public func validate() throws {
        try Self.validateMaxTokens(maxTokens)
        try Self.validateTemperature(temperature)
        try Self.validateTopP(topP)
        try Self.validateTopK(topK)
        
        guard !messages.isEmpty else {
            throw AnthropicError.invalidParameter("messages array cannot be empty")
        }
        
        // Validate tools if provided
        if let tools = tools {
            for tool in tools {
                try tool.validate()
            }
            
            // Ensure tool names are unique
            let toolNames = tools.map { $0.name }
            let uniqueNames = Set(toolNames)
            guard toolNames.count == uniqueNames.count else {
                throw AnthropicError.invalidParameter("Tool names must be unique")
            }
        }
        
        // Validate tool choice if provided
        if let toolChoice = toolChoice {
            if case .tool(let toolName) = toolChoice {
                guard let tools = tools, tools.contains(where: { $0.name == toolName }) else {
                    throw AnthropicError.invalidParameter("Tool choice references unknown tool: \(toolName)")
                }
            }
        }
    }
}

/// Resource for managing message operations
public actor MessagesResource {
    private let httpClient: HTTPClient
    private let apiKey: String
    private let baseURL: URL
    
    /// Creates a new messages resource
    /// - Parameters:
    ///   - httpClient: The HTTP client to use for requests
    ///   - apiKey: The API key for authentication
    ///   - baseURL: The base URL for the API
    init(httpClient: HTTPClient, apiKey: String, baseURL: URL) {
        self.httpClient = httpClient
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    /// Creates a new message using the Anthropic API
    /// - Parameter request: The message creation request with all parameters
    /// - Returns: The message response from the API containing the generated content
    /// - Throws: AnthropicError for validation errors, HTTPError for network issues, or decoding errors
    public func create(_ request: CreateMessageRequest) async throws -> MessageResponse {
        // Validate all request parameters
        try request.validate()
        
        let url = baseURL.appendingPathComponent("v1/messages")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let requestBody = try encoder.encode(request)
        
        let httpRequest = HTTPRequest(
            url: url,
            method: .POST,
            headers: [
                "x-api-key": apiKey,
                "Content-Type": "application/json",
                "anthropic-version": "2023-06-01",
                "User-Agent": "AnthropicSDK/1.0.0"
            ],
            body: requestBody
        )
        
        do {
            return try await httpClient.send(httpRequest)
        } catch let httpError as HTTPError {
            // Map specific HTTP status codes to more meaningful errors
            switch httpError {
            case .httpError(let statusCode):
                switch statusCode {
                case 400:
                    throw AnthropicError.invalidParameter("Invalid request parameters")
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
    
    /// Convenience method to create a message with model, messages, and maxTokens
    /// - Parameters:
    ///   - model: The Claude model to use
    ///   - messages: The conversation messages
    ///   - maxTokens: Maximum tokens to generate
    /// - Returns: The message response from the API
    /// - Throws: HTTPError or decoding errors
    public func create(model: ClaudeModel, messages: [Message], maxTokens: Int) async throws -> MessageResponse {
        let request = CreateMessageRequest(model: model, messages: messages, maxTokens: maxTokens)
        return try await create(request)
    }
    
    /// Creates a streaming message using the Anthropic API
    /// - Parameter request: The message creation request with all parameters
    /// - Returns: An AsyncSequence of streaming chunks for real-time response processing
    /// - Throws: AnthropicError for validation errors, HTTPError for network issues
    public func stream(_ request: CreateMessageRequest) async throws -> MessageStream {
        // Validate all request parameters
        try request.validate()
        
        let url = baseURL.appendingPathComponent("v1/messages")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        // Create streaming request with stream=true parameter
        let requestDict = try JSONSerialization.jsonObject(with: encoder.encode(request)) as! [String: Any]
        var streamingDict = requestDict
        streamingDict["stream"] = true
        
        let requestBody = try JSONSerialization.data(withJSONObject: streamingDict)
        
        let httpRequest = HTTPRequest(
            url: url,
            method: .POST,
            headers: [
                "x-api-key": apiKey,
                "Content-Type": "application/json",
                "anthropic-version": "2023-06-01",
                "User-Agent": "AnthropicSDK/1.0.0",
                "Accept": "text/event-stream"  // Enable streaming
            ],
            body: requestBody
        )
        
        return MessageStream(httpClient: httpClient, request: httpRequest)
    }
    
    /// Convenience method to create a streaming message with model, messages, and maxTokens
    /// - Parameters:
    ///   - model: The Claude model to use
    ///   - messages: The conversation messages
    ///   - maxTokens: Maximum tokens to generate
    /// - Returns: An AsyncSequence of streaming chunks for real-time response processing
    /// - Throws: HTTPError or decoding errors
    public func stream(model: ClaudeModel, messages: [Message], maxTokens: Int) async throws -> MessageStream {
        let request = CreateMessageRequest(model: model, messages: messages, maxTokens: maxTokens)
        return try await stream(request)
    }
    
    /// Creates a message with Extended Thinking capabilities
    /// - Parameter request: The message creation request with thinking mode
    /// - Returns: The extended message response with thinking data
    /// - Throws: AnthropicError for validation errors, HTTPError for network issues, or decoding errors
    public func createWithThinking(_ request: CreateMessageRequest) async throws -> ExtendedMessageResponse {
        // Validate all request parameters
        try request.validate()
        
        let url = baseURL.appendingPathComponent("v1/messages")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let requestBody = try encoder.encode(request)
        
        let httpRequest = HTTPRequest(
            url: url,
            method: .POST,
            headers: [
                "x-api-key": apiKey,
                "Content-Type": "application/json",
                "anthropic-version": "2023-06-01",
                "User-Agent": "AnthropicSDK/1.0.0"
            ],
            body: requestBody
        )
        
        do {
            return try await httpClient.send(httpRequest)
        } catch let httpError as HTTPError {
            // Map specific HTTP status codes to more meaningful errors
            switch httpError {
            case .httpError(let statusCode):
                switch statusCode {
                case 400:
                    throw AnthropicError.invalidParameter("Invalid request parameters")
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
}