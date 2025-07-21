import Foundation

/// Extended Thinking mode for accessing Claude's reasoning process
public enum ThinkingMode: String, Codable, CaseIterable, Equatable {
    /// Standard mode without thinking steps (default)
    case standard = "standard"
    /// Extended mode with access to reasoning steps
    case extended = "extended"
    /// Deep thinking mode with more detailed reasoning
    case deep = "deep"
}

/// Types of thinking steps in Claude's reasoning process
public enum ThinkingStepType: String, Codable, CaseIterable {
    case analysis = "analysis"
    case reasoning = "reasoning"
    case planning = "planning"
    case evaluation = "evaluation"
    case reflection = "reflection"
    case hypothesis = "hypothesis"
    case conclusion = "conclusion"
}

/// Represents a thinking step in Claude's reasoning process
public struct ThinkingStep: Codable, Equatable {
    /// The thinking content/reasoning text
    public let content: String
    /// Type of thinking step (reasoning, analysis, etc.)
    public let type: String?
    /// Confidence level of this reasoning step (0.0-1.0)
    public let confidence: Double?
    /// Step number in the reasoning sequence
    public let stepNumber: Int?
    
    /// Creates a new thinking step
    /// - Parameters:
    ///   - content: The thinking content
    ///   - type: Type of thinking step
    ///   - confidence: Confidence level (optional)
    ///   - stepNumber: Step sequence number (optional)
    public init(content: String, type: String? = nil, confidence: Double? = nil, stepNumber: Int? = nil) {
        self.content = content
        self.type = type
        self.confidence = confidence
        self.stepNumber = stepNumber
    }
    
    /// Creates a new thinking step with a typed step type
    /// - Parameters:
    ///   - content: The thinking content
    ///   - stepType: Strongly typed step type
    ///   - confidence: Confidence level (optional)
    ///   - stepNumber: Step sequence number (optional)
    public init(content: String, stepType: ThinkingStepType, confidence: Double? = nil, stepNumber: Int? = nil) {
        self.content = content
        self.type = stepType.rawValue
        self.confidence = confidence
        self.stepNumber = stepNumber
    }
    
    /// The thinking step type as an enum (if it matches a known type)
    public var stepType: ThinkingStepType? {
        guard let type = type else { return nil }
        return ThinkingStepType(rawValue: type)
    }
    
    /// Whether this step has high confidence (>= 0.8)
    public var isHighConfidence: Bool {
        guard let confidence = confidence else { return false }
        return confidence >= 0.8
    }
    
    private enum CodingKeys: String, CodingKey {
        case content
        case type
        case confidence
        case stepNumber = "step_number"
    }
}

/// Represents thinking content in a message response
public struct ThinkingContent: Codable, Equatable {
    /// The raw thinking text
    public let text: String
    /// Structured thinking steps if available
    public let steps: [ThinkingStep]?
    /// Total thinking tokens used
    public let thinkingTokens: Int?
    /// Reasoning quality score (0.0-1.0)
    public let reasoningScore: Double?
    
    /// Creates new thinking content
    /// - Parameters:
    ///   - text: The thinking text
    ///   - steps: Structured thinking steps (optional)
    ///   - thinkingTokens: Token count (optional)
    ///   - reasoningScore: Quality score (optional)
    public init(text: String, steps: [ThinkingStep]? = nil, thinkingTokens: Int? = nil, reasoningScore: Double? = nil) {
        self.text = text
        self.steps = steps
        self.thinkingTokens = thinkingTokens
        self.reasoningScore = reasoningScore
    }
    
    private enum CodingKeys: String, CodingKey {
        case text
        case steps
        case thinkingTokens = "thinking_tokens"
        case reasoningScore = "reasoning_score"
    }
    
    /// Filters thinking steps by type
    /// - Parameter stepType: The type of steps to filter for
    /// - Returns: Array of steps matching the specified type
    public func steps(ofType stepType: ThinkingStepType) -> [ThinkingStep] {
        return steps?.filter { $0.stepType == stepType } ?? []
    }
    
    /// Gets high confidence thinking steps (>= 0.8)
    /// - Returns: Array of high confidence steps
    public var highConfidenceSteps: [ThinkingStep] {
        return steps?.filter { $0.isHighConfidence } ?? []
    }
    
    /// Whether the reasoning quality is high (>= 0.8)
    public var isHighQualityReasoning: Bool {
        guard let score = reasoningScore else { return false }
        return score >= 0.8
    }
    
    /// Summary of thinking step types present
    public var stepTypeSummary: [ThinkingStepType: Int] {
        guard let steps = steps else { return [:] }
        
        var summary: [ThinkingStepType: Int] = [:]
        for step in steps {
            if let stepType = step.stepType {
                summary[stepType, default: 0] += 1
            }
        }
        return summary
    }
}

/// Extended usage statistics including thinking tokens
public struct ExtendedUsage: Codable, Equatable {
    /// Input tokens used
    public let inputTokens: Int
    /// Output tokens generated
    public let outputTokens: Int
    /// Thinking tokens used for reasoning
    public let thinkingTokens: Int?
    /// Cache tokens used (if applicable)
    public let cacheTokens: Int?
    
    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case thinkingTokens = "thinking_tokens"
        case cacheTokens = "cache_tokens"
    }
    
    public init(inputTokens: Int, outputTokens: Int, thinkingTokens: Int? = nil, cacheTokens: Int? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.thinkingTokens = thinkingTokens
        self.cacheTokens = cacheTokens
    }
    
    /// Total tokens used across all categories
    public var totalTokens: Int {
        return inputTokens + outputTokens + (thinkingTokens ?? 0) + (cacheTokens ?? 0)
    }
}

/// Response from Anthropic API with Extended Thinking capabilities
public struct ExtendedMessageResponse: Codable, Equatable {
    public let id: String
    public let type: String
    public let role: MessageRole
    public let content: [Content]
    public let model: String
    public let stopReason: String?
    public let stopSequence: String?
    public let usage: ExtendedUsage
    /// Thinking content if Extended Thinking was enabled
    public let thinking: ThinkingContent?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case content
        case model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
        case thinking
    }
    
    public init(id: String, type: String, role: MessageRole, content: [Content], 
                model: String, stopReason: String?, stopSequence: String?, 
                usage: ExtendedUsage, thinking: ThinkingContent? = nil) {
        self.id = id
        self.type = type
        self.role = role
        self.content = content
        self.model = model
        self.stopReason = stopReason
        self.stopSequence = stopSequence
        self.usage = usage
        self.thinking = thinking
    }
    
    /// Whether this response includes thinking data
    public var hasThinkingData: Bool {
        return thinking != nil
    }
    
    /// Gets the final response text (combining all text content)
    public var responseText: String {
        return content.compactMap { content in
            if case .text(let text) = content {
                return text
            }
            return nil
        }.joined(separator: "\n")
    }
    
    /// Whether the thinking process was high quality (>= 0.8 reasoning score)
    public var isHighQualityThinking: Bool {
        return thinking?.isHighQualityReasoning ?? false
    }
    
    /// Thinking efficiency ratio (output tokens per thinking token)
    public var thinkingEfficiency: Double? {
        guard let thinkingTokens = usage.thinkingTokens, thinkingTokens > 0 else { return nil }
        return Double(usage.outputTokens) / Double(thinkingTokens)
    }
}

/// Streaming chunk for Extended Thinking content
public enum ExtendedStreamingChunk: Codable {
    case messageStart(MessageStartChunk)
    case contentBlockStart(ContentBlockStartChunk)
    case contentBlockDelta(ContentBlockDeltaChunk)
    case contentBlockStop(ContentBlockStopChunk)
    case thinkingStart(ThinkingStartChunk)
    case thinkingDelta(ThinkingDeltaChunk)
    case thinkingStop(ThinkingStopChunk)
    case messageStop(MessageStopChunk)
    case error(StreamingErrorChunk)
    
    /// The type string identifier for this chunk
    public var type: String {
        switch self {
        case .messageStart: return "message_start"
        case .contentBlockStart: return "content_block_start"
        case .contentBlockDelta: return "content_block_delta"
        case .contentBlockStop: return "content_block_stop"
        case .thinkingStart: return "thinking_start"
        case .thinkingDelta: return "thinking_delta"
        case .thinkingStop: return "thinking_stop"
        case .messageStop: return "message_stop"
        case .error: return "error"
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "message_start":
            let chunk = try MessageStartChunk(from: decoder)
            self = .messageStart(chunk)
        case "content_block_start":
            let chunk = try ContentBlockStartChunk(from: decoder)
            self = .contentBlockStart(chunk)
        case "content_block_delta":
            let chunk = try ContentBlockDeltaChunk(from: decoder)
            self = .contentBlockDelta(chunk)
        case "content_block_stop":
            let chunk = try ContentBlockStopChunk(from: decoder)
            self = .contentBlockStop(chunk)
        case "thinking_start":
            let chunk = try ThinkingStartChunk(from: decoder)
            self = .thinkingStart(chunk)
        case "thinking_delta":
            let chunk = try ThinkingDeltaChunk(from: decoder)
            self = .thinkingDelta(chunk)
        case "thinking_stop":
            let chunk = try ThinkingStopChunk(from: decoder)
            self = .thinkingStop(chunk)
        case "message_stop":
            let chunk = try MessageStopChunk(from: decoder)
            self = .messageStop(chunk)
        case "error":
            let chunk = try StreamingErrorChunk(from: decoder)
            self = .error(chunk)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown chunk type: \(type)")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .messageStart(let chunk):
            try chunk.encode(to: encoder)
        case .contentBlockStart(let chunk):
            try chunk.encode(to: encoder)
        case .contentBlockDelta(let chunk):
            try chunk.encode(to: encoder)
        case .contentBlockStop(let chunk):
            try chunk.encode(to: encoder)
        case .thinkingStart(let chunk):
            try chunk.encode(to: encoder)
        case .thinkingDelta(let chunk):
            try chunk.encode(to: encoder)
        case .thinkingStop(let chunk):
            try chunk.encode(to: encoder)
        case .messageStop(let chunk):
            try chunk.encode(to: encoder)
        case .error(let chunk):
            try chunk.encode(to: encoder)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
}

/// Chunk indicating thinking process has started
public struct ThinkingStartChunk: Codable, Equatable {
    public let type: String
    public let index: Int
    
    public init(type: String = "thinking_start", index: Int) {
        self.type = type
        self.index = index
    }
}

/// Chunk containing incremental thinking content
public struct ThinkingDeltaChunk: Codable, Equatable {
    public let type: String
    public let index: Int
    public let delta: ThinkingDelta
    
    public init(type: String = "thinking_delta", index: Int, delta: ThinkingDelta) {
        self.type = type
        self.index = index
        self.delta = delta
    }
}

/// Delta content for thinking steps
public struct ThinkingDelta: Codable, Equatable {
    public let type: String
    public let text: String?
    public let step: ThinkingStep?
    
    public init(type: String, text: String? = nil, step: ThinkingStep? = nil) {
        self.type = type
        self.text = text
        self.step = step
    }
}

/// Chunk indicating thinking process has stopped
public struct ThinkingStopChunk: Codable, Equatable {
    public let type: String
    public let index: Int
    public let thinking: ThinkingContent?
    
    public init(type: String = "thinking_stop", index: Int, thinking: ThinkingContent? = nil) {
        self.type = type
        self.index = index
        self.thinking = thinking
    }
}