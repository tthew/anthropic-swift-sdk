import Foundation

/// Represents the role of a message participant in a conversation
public enum MessageRole: String, Codable, CaseIterable, Equatable {
    /// Messages from the user
    case user = "user"
    /// Messages from the AI assistant
    case assistant = "assistant"
    /// System-level instructions and context
    case system = "system"
}

/// Represents different types of content that can be included in a message
public enum Content: Codable {
    case text(String)
    case image(ImageSource)
    case toolUse(ToolUse)
    case toolResult(ToolResult)
    
    public enum ImageSource: Codable, Equatable {
        case base64(mediaType: String, data: String)
        
        private enum CodingKeys: String, CodingKey {
            case type
            case mediaType = "media_type"
            case data
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "base64":
                let mediaType = try container.decode(String.self, forKey: .mediaType)
                let data = try container.decode(String.self, forKey: .data)
                self = .base64(mediaType: mediaType, data: data)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown image source type: \(type)")
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .base64(let mediaType, let data):
                try container.encode("base64", forKey: .type)
                try container.encode(mediaType, forKey: .mediaType)
                try container.encode(data, forKey: .data)
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case source
        case id
        case name
        case input
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image":
            let source = try container.decode(ImageSource.self, forKey: .source)
            self = .image(source)
        case "tool_use":
            let toolUse = try ToolUse(from: decoder)
            self = .toolUse(toolUse)
        case "tool_result":
            let toolResult = try ToolResult(from: decoder)
            self = .toolResult(toolResult)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type: \(type)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let source):
            try container.encode("image", forKey: .type)
            try container.encode(source, forKey: .source)
        case .toolUse(let toolUse):
            try container.encode("tool_use", forKey: .type)
            try toolUse.encode(to: encoder)
        case .toolResult(let toolResult):
            try container.encode("tool_result", forKey: .type)
            try toolResult.encode(to: encoder)
        }
    }
}

// MARK: - Equatable implementation for Content
extension Content: Equatable {
    public static func == (lhs: Content, rhs: Content) -> Bool {
        switch (lhs, rhs) {
        case (.text(let lhsText), .text(let rhsText)):
            return lhsText == rhsText
        case (.image(let lhsSource), .image(let rhsSource)):
            return lhsSource == rhsSource
        case (.toolUse(let lhsToolUse), .toolUse(let rhsToolUse)):
            return lhsToolUse == rhsToolUse
        case (.toolResult(let lhsToolResult), .toolResult(let rhsToolResult)):
            return lhsToolResult == rhsToolResult
        default:
            return false
        }
    }
}

/// Represents a message in a conversation with Claude
public struct Message: Codable, Equatable {
    /// The role of the message sender
    public let role: MessageRole
    /// The content blocks of the message
    public let content: [Content]
    
    /// Creates a new message with the specified role and content
    /// - Parameters:
    ///   - role: The role of the message sender
    ///   - content: Array of content blocks
    public init(role: MessageRole, content: [Content]) {
        self.role = role
        self.content = content
    }
    
    /// Creates a user message with text content
    /// - Parameter text: The text content of the message
    /// - Returns: A user message with the specified text
    public static func user(_ text: String) -> Message {
        return Message(role: .user, content: [.text(text)])
    }
    
    /// Creates an assistant message with text content
    /// - Parameter text: The text content of the message
    /// - Returns: An assistant message with the specified text
    public static func assistant(_ text: String) -> Message {
        return Message(role: .assistant, content: [.text(text)])
    }
    
    /// Creates a system message with text content
    /// - Parameter text: The text content of the message
    /// - Returns: A system message with the specified text
    public static func system(_ text: String) -> Message {
        return Message(role: .system, content: [.text(text)])
    }
}

/// Available Claude models with their capabilities and context windows
public enum ClaudeModel: String, CaseIterable, Codable, Equatable {
    /// Claude 4 Opus - World's most intelligent model with hybrid reasoning for complex coding and agentic workflows
    case claude4Opus = "claude-4-opus-20250522"
    /// Claude 4 Sonnet - Advanced model with hybrid reasoning, superior coding and precise instruction following
    case claude4Sonnet = "claude-4-sonnet-20250522"
    /// Claude 3.5 Sonnet - Fastest, most intelligent model for complex tasks
    case claude3_5Sonnet = "claude-3-5-sonnet-20241022"
    /// Claude 3.5 Haiku - Fast and lightweight for everyday tasks
    case claude3_5Haiku = "claude-3-5-haiku-20241022"
    /// Claude 3 Opus - Most powerful model for highly complex tasks
    case claude3Opus = "claude-3-opus-20240229"
    /// Claude 3 Sonnet - Balanced intelligence and speed
    case claude3Sonnet = "claude-3-sonnet-20240229"
    /// Claude 3 Haiku - Fastest model for simple tasks
    case claude3Haiku = "claude-3-haiku-20240307"
    
    /// The maximum context window size for this model
    public var contextWindow: Int {
        switch self {
        case .claude4Opus, .claude4Sonnet:
            return 200_000
        case .claude3_5Sonnet, .claude3_5Haiku:
            return 200_000
        case .claude3Opus, .claude3Sonnet, .claude3Haiku:
            return 200_000
        }
    }
    
    /// Whether this model supports vision (image input)
    public var supportsVision: Bool {
        switch self {
        case .claude4Opus, .claude4Sonnet:
            return true
        case .claude3_5Sonnet, .claude3Opus, .claude3Sonnet, .claude3Haiku:
            return true
        case .claude3_5Haiku:
            return false
        }
    }
}

/// Token usage statistics
public struct Usage: Codable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int
    
    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
    
    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

/// Response from the Anthropic Messages API
public struct MessageResponse: Codable, Equatable {
    public let id: String
    public let type: String
    public let role: MessageRole
    public let content: [Content]
    public let model: String
    public let stopReason: String?
    public let stopSequence: String?
    public let usage: Usage
    
    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case content
        case model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
    
    public init(id: String, type: String, role: MessageRole, content: [Content], 
                model: String, stopReason: String?, stopSequence: String?, usage: Usage) {
        self.id = id
        self.type = type
        self.role = role
        self.content = content
        self.model = model
        self.stopReason = stopReason
        self.stopSequence = stopSequence
        self.usage = usage
    }
}