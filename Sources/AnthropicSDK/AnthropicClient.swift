import Foundation

/// A closure that handles tool execution
/// - Parameters:
///   - name: The name of the tool to execute
///   - input: The input parameters for the tool
/// - Returns: The result of tool execution
public typealias ToolHandler = (String, [String: Any]) async throws -> String

/// Errors that can occur when working with the Anthropic SDK
public enum AnthropicError: Error, LocalizedError {
    /// The provided API key is invalid or malformed
    case invalidAPIKey
    /// The API key is empty or missing
    case emptyAPIKey
    /// No API key found in environment variable
    case missingEnvironmentKey
    /// Invalid parameter value
    case invalidParameter(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key format. API keys must start with 'sk-ant-'"
        case .emptyAPIKey:
            return "API key cannot be empty"
        case .missingEnvironmentKey:
            return "No API key found in ANTHROPIC_API_KEY environment variable"
        case .invalidParameter(let message):
            return "Invalid parameter: \(message)"
        }
    }
}

/// The main client for interacting with the Anthropic API
public struct AnthropicClient {
    /// The API key used for authentication
    public let apiKey: String
    /// The base URL for API requests
    public let baseURL: URL
    /// The HTTP client for making requests
    private let httpClient: HTTPClient
    /// Messages resource for message operations
    public let messages: MessagesResource
    /// Batches resource for batch operations
    public let batches: BatchesResource
    /// Files resource for file operations
    public let files: FilesResource
    
    /// Creates a new client with the provided API key
    /// - Parameters:
    ///   - apiKey: A valid Anthropic API key starting with "sk-ant-"
    ///   - baseURL: The base URL for API requests (optional, defaults to Anthropic API)
    /// - Throws: `AnthropicError` if the API key is invalid or empty
    public init(apiKey: String, baseURL: URL = URL(string: "https://api.anthropic.com")!) throws {
        guard !apiKey.isEmpty else {
            throw AnthropicError.emptyAPIKey
        }
        
        guard apiKey.hasPrefix("sk-ant-") else {
            throw AnthropicError.invalidAPIKey
        }
        
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.httpClient = HTTPClient()
        self.messages = MessagesResource(httpClient: httpClient, apiKey: apiKey, baseURL: baseURL)
        self.batches = BatchesResource(httpClient: httpClient, apiKey: apiKey, baseURL: baseURL)
        self.files = FilesResource(httpClient: httpClient, apiKey: apiKey, baseURL: baseURL)
    }
    
    /// Creates a new client using the API key from the ANTHROPIC_API_KEY environment variable
    /// - Parameter baseURL: The base URL for API requests (optional, defaults to Anthropic API)
    /// - Throws: `AnthropicError` if no environment variable is set or the key is invalid
    public init(baseURL: URL = URL(string: "https://api.anthropic.com")!) throws {
        guard let envAPIKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] else {
            throw AnthropicError.missingEnvironmentKey
        }
        
        try self.init(apiKey: envAPIKey, baseURL: baseURL)
    }
    
    /// Convenience method to send a simple text message
    /// - Parameters:
    ///   - text: The text message to send
    ///   - model: The Claude model to use (defaults to Claude 3.5 Sonnet)
    ///   - maxTokens: Maximum tokens to generate (defaults to 1000)
    /// - Returns: The message response from the API
    /// - Throws: HTTPError or decoding errors
    public func sendMessage(_ text: String, 
                           model: ClaudeModel = .claude3_5Sonnet, 
                           maxTokens: Int = 1000) async throws -> MessageResponse {
        return try await messages.create(
            model: model,
            messages: [.user(text)],
            maxTokens: maxTokens
        )
    }
    
    /// Convenience method to stream a simple text message
    /// - Parameters:
    ///   - text: The text message to send
    ///   - model: The Claude model to use (defaults to Claude 3.5 Sonnet)
    ///   - maxTokens: Maximum tokens to generate (defaults to 1000)
    /// - Returns: An AsyncSequence of streaming chunks for real-time response processing
    /// - Throws: HTTPError or decoding errors
    public func streamMessage(_ text: String, 
                             model: ClaudeModel = .claude3_5Sonnet, 
                             maxTokens: Int = 1000) async throws -> MessageStream {
        return try await messages.stream(
            model: model,
            messages: [.user(text)],
            maxTokens: maxTokens
        )
    }
    
    /// Sends a message with tools and handles tool execution automatically
    /// - Parameters:
    ///   - text: The text message to send
    ///   - tools: The tools available for Claude to use
    ///   - toolHandler: A closure to handle tool execution
    ///   - model: The Claude model to use (defaults to Claude 3.5 Sonnet)
    ///   - maxTokens: Maximum tokens to generate (defaults to 1000)
    /// - Returns: The final message response after tool execution
    /// - Throws: HTTPError or decoding errors
    public func sendMessageWithTools(
        _ text: String,
        tools: [Tool],
        toolHandler: ToolHandler,
        model: ClaudeModel = .claude3_5Sonnet,
        maxTokens: Int = 1000
    ) async throws -> MessageResponse {
        var conversationMessages: [Message] = [.user(text)]
        
        // Create initial request with tools
        let request = CreateMessageRequest(
            model: model,
            messages: conversationMessages,
            maxTokens: maxTokens,
            tools: tools
        )
        
        var response = try await messages.create(request)
        
        // Handle tool use loop
        while let toolUseContent = response.content.first(where: { 
            if case .toolUse = $0 { return true }
            return false
        }) {
            if case .toolUse(let toolUse) = toolUseContent {
                do {
                    // Execute the tool
                    let result = try await toolHandler(toolUse.name, toolUse.input)
                    
                    // Add Claude's response to conversation
                    conversationMessages.append(Message(role: .assistant, content: response.content))
                    
                    // Add tool result to conversation
                    let toolResult = ToolResult(toolUseId: toolUse.id, content: result)
                    conversationMessages.append(Message(role: .user, content: [.toolResult(toolResult)]))
                    
                    // Continue conversation
                    let followUpRequest = CreateMessageRequest(
                        model: model,
                        messages: conversationMessages,
                        maxTokens: maxTokens,
                        tools: tools
                    )
                    
                    response = try await messages.create(followUpRequest)
                } catch {
                    // Handle tool execution error
                    let errorResult = ToolResult(
                        toolUseId: toolUse.id, 
                        content: "Error executing tool: \(error.localizedDescription)",
                        isError: true
                    )
                    
                    // Add Claude's response to conversation
                    conversationMessages.append(Message(role: .assistant, content: response.content))
                    
                    // Add error result to conversation
                    conversationMessages.append(Message(role: .user, content: [.toolResult(errorResult)]))
                    
                    // Continue conversation with error
                    let followUpRequest = CreateMessageRequest(
                        model: model,
                        messages: conversationMessages,
                        maxTokens: maxTokens,
                        tools: tools
                    )
                    
                    response = try await messages.create(followUpRequest)
                }
            }
        }
        
        return response
    }
    
    /// Sends a message with Extended Thinking to access Claude's reasoning process
    /// - Parameters:
    ///   - text: The text message to send
    ///   - thinkingMode: The thinking mode to use (extended or deep)
    ///   - model: The Claude model to use (defaults to Claude 3.5 Sonnet)
    ///   - maxTokens: Maximum tokens to generate (defaults to 1000)
    /// - Returns: The extended message response with thinking data
    /// - Throws: HTTPError or decoding errors
    public func sendMessageWithThinking(
        _ text: String,
        thinkingMode: ThinkingMode = .extended,
        model: ClaudeModel = .claude3_5Sonnet,
        maxTokens: Int = 1000
    ) async throws -> ExtendedMessageResponse {
        let request = CreateMessageRequest(
            model: model,
            messages: [.user(text)],
            maxTokens: maxTokens,
            thinkingMode: thinkingMode
        )
        
        return try await messages.createWithThinking(request)
    }
}