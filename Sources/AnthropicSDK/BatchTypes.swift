import Foundation


/// Represents a single request in a batch operation
public struct BatchRequest: Codable, Equatable {
    /// Custom identifier for tracking this request
    public let customId: String
    /// HTTP method for the request
    public let method: HTTPMethod
    /// API endpoint URL for the request
    public let url: String
    /// Request body containing the message creation parameters
    public let body: CreateMessageRequest
    
    /// Creates a new batch request
    /// - Parameters:
    ///   - customId: Unique identifier for tracking
    ///   - method: HTTP method (typically POST for messages)
    ///   - url: API endpoint (typically "/v1/messages")
    ///   - body: The message creation request
    public init(customId: String, method: HTTPMethod, url: String, body: CreateMessageRequest) {
        self.customId = customId
        self.method = method
        self.url = url
        self.body = body
    }
    
    private enum CodingKeys: String, CodingKey {
        case customId = "custom_id"
        case method
        case url
        case body
    }
    
    /// Validates the batch request parameters
    /// - Throws: AnthropicError if validation fails
    public func validate() throws {
        guard !customId.isEmpty else {
            throw AnthropicError.invalidParameter("Batch request custom_id cannot be empty")
        }
        
        guard !url.isEmpty else {
            throw AnthropicError.invalidParameter("Batch request URL cannot be empty")
        }
        
        // Validate the underlying message request
        try body.validate()
    }
}

/// Processing status of a batch operation
public enum BatchStatus: String, Codable, CaseIterable, Equatable {
    /// Batch is currently being processed
    case inProgress = "in_progress"
    /// Batch is in the process of being cancelled
    case canceling = "canceling"
    /// Batch has been cancelled
    case cancelled = "cancelled"
    /// Batch processing has completed
    case ended = "ended"
    
    /// Whether the batch is still active (not completed or cancelled)
    public var isActive: Bool {
        switch self {
        case .inProgress, .canceling:
            return true
        case .cancelled, .ended:
            return false
        }
    }
}

/// Counts of requests in different processing states
public struct BatchRequestCounts: Codable, Equatable {
    /// Number of requests currently being processed
    public let processing: Int
    /// Number of requests that completed successfully
    public let succeeded: Int
    /// Number of requests that failed with errors
    public let errored: Int
    /// Number of requests that were cancelled
    public let cancelled: Int
    
    /// Total number of requests in the batch
    public var total: Int {
        return processing + succeeded + errored + cancelled
    }
    
    /// Whether all requests have completed (successfully or with errors)
    public var allCompleted: Bool {
        return processing == 0
    }
    
    /// Success rate as a percentage (0.0-1.0)
    public var successRate: Double {
        let completed = succeeded + errored
        guard completed > 0 else { return 0.0 }
        return Double(succeeded) / Double(completed)
    }
    
    public init(processing: Int, succeeded: Int, errored: Int, cancelled: Int) {
        self.processing = processing
        self.succeeded = succeeded
        self.errored = errored
        self.cancelled = cancelled
    }
}

/// Represents a batch of message processing requests
public struct Batch: Codable, Equatable {
    /// Unique identifier for the batch
    public let id: String
    /// Object type (always "message_batch")
    public let type: String
    /// Current processing status of the batch
    public let processingStatus: BatchStatus
    /// Counts of requests in different states
    public let requestCounts: BatchRequestCounts
    /// When the batch processing ended (if completed)
    public let endedAt: Date?
    /// When the batch was created
    public let createdAt: Date
    /// When the batch will expire if not processed
    public let expiresAt: Date
    /// When the batch results were archived (if applicable)
    public let archivedAt: Date?
    /// When the batch was cancelled (if cancelled)
    public let cancelledAt: Date?
    /// URL to download batch results (if available)
    public let resultsUrl: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case processingStatus = "processing_status"
        case requestCounts = "request_counts"
        case endedAt = "ended_at"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case archivedAt = "archived_at"
        case cancelledAt = "cancelled_at"
        case resultsUrl = "results_url"
    }
    
    public init(id: String, type: String, processingStatus: BatchStatus, requestCounts: BatchRequestCounts,
                endedAt: Date?, createdAt: Date, expiresAt: Date, archivedAt: Date?, 
                cancelledAt: Date?, resultsUrl: String?) {
        self.id = id
        self.type = type
        self.processingStatus = processingStatus
        self.requestCounts = requestCounts
        self.endedAt = endedAt
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.archivedAt = archivedAt
        self.cancelledAt = cancelledAt
        self.resultsUrl = resultsUrl
    }
    
    /// Whether the batch has completed processing
    public var isCompleted: Bool {
        return processingStatus == .ended || processingStatus == .cancelled
    }
    
    /// Whether batch results are available for download
    public var hasResults: Bool {
        return resultsUrl != nil && isCompleted
    }
    
    /// Time remaining before batch expires (if not completed)
    public var timeUntilExpiration: TimeInterval? {
        guard !isCompleted else { return nil }
        return expiresAt.timeIntervalSinceNow
    }
}

/// Error information for failed batch requests
public struct BatchError: Codable, Equatable {
    /// Error type identifier
    public let type: String
    /// Human-readable error message
    public let message: String
    /// Additional error details (if available)
    public let details: [String: String]?
    
    public init(type: String, message: String, details: [String: String]? = nil) {
        self.type = type
        self.message = message
        self.details = details
    }
}

/// Result data for a batch request (success or error)
public enum BatchResultData: Codable, Equatable {
    case success(MessageResponse)
    case error(BatchError)
    
    /// Whether this result represents a successful request
    public var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    /// The error information if this result represents a failure
    public var error: BatchError? {
        if case .error(let batchError) = self {
            return batchError
        }
        return nil
    }
    
    /// The message response if this result represents success
    public var response: MessageResponse? {
        if case .success(let messageResponse) = self {
            return messageResponse
        }
        return nil
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "succeeded":
            let message = try container.decode(MessageResponse.self, forKey: .message)
            self = .success(message)
        case "errored":
            let error = try container.decode(BatchError.self, forKey: .error)
            self = .error(error)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, 
                in: container, 
                debugDescription: "Unknown batch result type: \(type)"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .success(let message):
            try container.encode("succeeded", forKey: .type)
            try container.encode(message, forKey: .message)
        case .error(let error):
            try container.encode("errored", forKey: .type)
            try container.encode(error, forKey: .error)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case message
        case error
    }
}

/// Result of a single request within a batch
public struct BatchResult: Codable, Equatable {
    /// The custom ID that was provided in the original request
    public let customId: String
    /// The result data (success with message or error)
    public let result: BatchResultData
    
    private enum CodingKeys: String, CodingKey {
        case customId = "custom_id"
        case result
    }
    
    public init(customId: String, result: BatchResultData) {
        self.customId = customId
        self.result = result
    }
    
    /// Whether this batch result represents a successful request
    public var isSuccess: Bool {
        return result.isSuccess
    }
}

/// Request to create a new batch
public struct CreateBatchRequest: Codable, Equatable {
    /// Array of requests to process in the batch
    public let requests: [BatchRequest]
    /// Optional completion webhook URL
    public let completionWindow: String?
    /// Optional metadata for the batch
    public let metadata: [String: String]?
    
    private enum CodingKeys: String, CodingKey {
        case requests
        case completionWindow = "completion_window"
        case metadata
    }
    
    public init(requests: [BatchRequest], completionWindow: String? = nil, metadata: [String: String]? = nil) {
        self.requests = requests
        self.completionWindow = completionWindow
        self.metadata = metadata
    }
    
    /// Validates the batch creation request
    /// - Throws: AnthropicError if validation fails
    public func validate() throws {
        guard !requests.isEmpty else {
            throw AnthropicError.invalidParameter("Batch requests array cannot be empty")
        }
        
        try Self.validateRequestCount(requests.count)
        try Self.validateUniqueCustomIds(requests)
        
        // Validate each individual request
        for request in requests {
            try request.validate()
        }
    }
    
    /// Validates the number of requests in a batch
    /// - Parameter count: Number of requests
    /// - Throws: AnthropicError if count exceeds limits
    public static func validateRequestCount(_ count: Int) throws {
        let maxRequests = 10000 // Example limit
        guard count <= maxRequests else {
            throw AnthropicError.invalidParameter("Batch cannot contain more than maximum \(maxRequests) requests")
        }
    }
    
    /// Validates that all custom IDs in the batch are unique
    /// - Parameter requests: Array of batch requests
    /// - Throws: AnthropicError if duplicate custom IDs are found
    public static func validateUniqueCustomIds(_ requests: [BatchRequest]) throws {
        let customIds = requests.map { $0.customId }
        let uniqueIds = Set(customIds)
        
        guard customIds.count == uniqueIds.count else {
            throw AnthropicError.invalidParameter("Batch requests must have unique custom_id values - duplicate IDs found")
        }
    }
}

/// Response from batch results endpoint
public struct BatchResultsResponse: Codable, Equatable {
    /// Array of batch results
    public let data: [BatchResult]
    /// Whether there are more results available
    public let hasMore: Bool
    /// ID of the first result (for pagination)
    public let firstId: String?
    /// ID of the last result (for pagination) 
    public let lastId: String?
    
    private enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case firstId = "first_id"
        case lastId = "last_id"
    }
    
    public init(data: [BatchResult], hasMore: Bool, firstId: String?, lastId: String?) {
        self.data = data
        self.hasMore = hasMore
        self.firstId = firstId
        self.lastId = lastId
    }
    
    /// Results grouped by success/failure
    public var successfulResults: [BatchResult] {
        return data.filter { $0.isSuccess }
    }
    
    /// Results that failed with errors
    public var failedResults: [BatchResult] {
        return data.filter { !$0.isSuccess }
    }
    
    /// Overall success rate for this page of results
    public var successRate: Double {
        guard !data.isEmpty else { return 0.0 }
        return Double(successfulResults.count) / Double(data.count)
    }
}