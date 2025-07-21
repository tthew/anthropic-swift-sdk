import Foundation

/// Resource for managing batch operations with the Anthropic API
///
/// Batch operations allow you to process multiple message requests efficiently in a single API call.
/// This is particularly useful for bulk processing, data analysis, and scenarios where you need
/// to process many messages simultaneously while managing rate limits effectively.
///
/// ## Basic Usage Example
///
/// ```swift
/// // Create batch requests
/// let requests = [
///     BatchRequest(
///         customId: "analysis_1",
///         method: .POST,
///         url: "/v1/messages",
///         body: CreateMessageRequest(
///             model: .claude3_5Sonnet,
///             messages: [.user("Analyze this data: [1,2,3,4,5]")],
///             maxTokens: 500
///         )
///     ),
///     BatchRequest(
///         customId: "analysis_2",
///         method: .POST,
///         url: "/v1/messages",
///         body: CreateMessageRequest(
///             model: .claude3_5Sonnet,
///             messages: [.user("Summarize the key trends in AI")],
///             maxTokens: 500
///         )
///     )
/// ]
///
/// // Submit batch for processing
/// let batch = try await client.batches.create(
///     CreateBatchRequest(requests: requests)
/// )
///
/// // Monitor progress
/// repeat {
///     let status = try await client.batches.retrieve(batch.id)
///     print("Progress: \(status.requestCounts.succeeded)/\(status.requestCounts.total)")
///     
///     if status.isCompleted {
///         // Get results
///         let results = try await client.batches.results(batch.id)
///         for result in results.data {
///             if result.isSuccess, let response = result.result.response {
///                 print("Result for \(result.customId): \(response.content)")
///             } else if let error = result.result.error {
///                 print("Error for \(result.customId): \(error.message)")
///             }
///         }
///         break
///     }
///     
///     try await Task.sleep(nanoseconds: 5_000_000_000) // Wait 5 seconds
/// } while true
/// ```
public actor BatchesResource {
    private let httpClient: HTTPClient
    private let apiKey: String
    private let baseURL: URL
    
    /// Creates a new batches resource
    /// - Parameters:
    ///   - httpClient: The HTTP client to use for requests
    ///   - apiKey: The API key for authentication
    ///   - baseURL: The base URL for the API
    init(httpClient: HTTPClient, apiKey: String, baseURL: URL) {
        self.httpClient = httpClient
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    /// Creates a new batch for processing multiple message requests
    /// - Parameter request: The batch creation request containing all requests to process
    /// - Returns: The created batch with ID and status information
    /// - Throws: AnthropicError for validation errors, HTTPError for network issues, or decoding errors
    public func create(_ request: CreateBatchRequest) async throws -> Batch {
        // Validate all request parameters
        try request.validate()
        
        let url = baseURL.appendingPathComponent("v1/messages/batches")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
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
                    throw AnthropicError.invalidParameter("Invalid batch request parameters")
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
    
    /// Convenience method to create a batch from an array of batch requests
    /// - Parameter requests: Array of batch requests to process
    /// - Returns: The created batch with ID and status information
    /// - Throws: AnthropicError for validation errors, HTTPError for network issues, or decoding errors
    public func create(_ requests: [BatchRequest]) async throws -> Batch {
        let request = CreateBatchRequest(requests: requests)
        return try await create(request)
    }
    
    /// Retrieves information about a specific batch
    /// - Parameter batchId: The unique identifier of the batch
    /// - Returns: Current batch status and progress information
    /// - Throws: HTTPError for network issues or decoding errors
    public func retrieve(_ batchId: String) async throws -> Batch {
        let url = baseURL.appendingPathComponent("v1/messages/batches/\(batchId)")
        
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
        
        return try await httpClient.send(httpRequest)
    }
    
    /// Cancels a batch that is currently in progress
    /// - Parameter batchId: The unique identifier of the batch to cancel
    /// - Returns: The updated batch with cancellation status
    /// - Throws: HTTPError for network issues or decoding errors
    public func cancel(_ batchId: String) async throws -> Batch {
        let url = baseURL.appendingPathComponent("v1/messages/batches/\(batchId)/cancel")
        
        let httpRequest = HTTPRequest(
            url: url,
            method: .POST,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
                "User-Agent": "AnthropicSDK/1.0.0"
            ],
            body: nil
        )
        
        return try await httpClient.send(httpRequest)
    }
    
    /// Retrieves results from a completed batch
    /// - Parameters:
    ///   - batchId: The unique identifier of the completed batch
    ///   - beforeId: Retrieve results before this ID (for pagination)
    ///   - afterId: Retrieve results after this ID (for pagination)
    ///   - limit: Maximum number of results to return (1-1000, default 20)
    /// - Returns: Paginated batch results with success and error information
    /// - Throws: HTTPError for network issues or decoding errors
    public func results(_ batchId: String, beforeId: String? = nil, afterId: String? = nil, limit: Int = 20) async throws -> BatchResultsResponse {
        var urlComponents = URLComponents(string: baseURL.appendingPathComponent("v1/messages/batches/\(batchId)/results").absoluteString)!
        var queryItems: [URLQueryItem] = []
        
        if let beforeId = beforeId {
            queryItems.append(URLQueryItem(name: "before_id", value: beforeId))
        }
        if let afterId = afterId {
            queryItems.append(URLQueryItem(name: "after_id", value: afterId))
        }
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        
        urlComponents.queryItems = queryItems
        
        let httpRequest = HTTPRequest(
            url: urlComponents.url!,
            method: .GET,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
                "User-Agent": "AnthropicSDK/1.0.0"
            ],
            body: nil
        )
        
        return try await httpClient.send(httpRequest)
    }
    
    /// Lists all batches for the account
    /// - Parameters:
    ///   - beforeId: List batches before this ID (for pagination)
    ///   - afterId: List batches after this ID (for pagination)
    ///   - limit: Maximum number of batches to return (1-100, default 20)
    /// - Returns: Paginated list of batches
    /// - Throws: HTTPError for network issues or decoding errors
    public func list(beforeId: String? = nil, afterId: String? = nil, limit: Int = 20) async throws -> BatchListResponse {
        var urlComponents = URLComponents(string: baseURL.appendingPathComponent("v1/messages/batches").absoluteString)!
        var queryItems: [URLQueryItem] = []
        
        if let beforeId = beforeId {
            queryItems.append(URLQueryItem(name: "before_id", value: beforeId))
        }
        if let afterId = afterId {
            queryItems.append(URLQueryItem(name: "after_id", value: afterId))
        }
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        
        urlComponents.queryItems = queryItems
        
        let httpRequest = HTTPRequest(
            url: urlComponents.url!,
            method: .GET,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
                "User-Agent": "AnthropicSDK/1.0.0"
            ],
            body: nil
        )
        
        return try await httpClient.send(httpRequest)
    }
}

/// Response from batch list endpoint
public struct BatchListResponse: Codable, Equatable {
    /// Array of batches
    public let data: [Batch]
    /// Whether there are more batches available
    public let hasMore: Bool
    /// ID of the first batch (for pagination)
    public let firstId: String?
    /// ID of the last batch (for pagination)
    public let lastId: String?
    
    private enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case firstId = "first_id"
        case lastId = "last_id"
    }
    
    public init(data: [Batch], hasMore: Bool, firstId: String?, lastId: String?) {
        self.data = data
        self.hasMore = hasMore
        self.firstId = firstId
        self.lastId = lastId
    }
    
    /// Batches currently being processed
    public var activeBatches: [Batch] {
        return data.filter { $0.processingStatus.isActive }
    }
    
    /// Completed batches (ended or cancelled)
    public var completedBatches: [Batch] {
        return data.filter { $0.isCompleted }
    }
}