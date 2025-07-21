import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Represents different types of streaming chunks from the Anthropic API
public enum StreamingChunk: Codable, Equatable {
    case messageStart(MessageStartChunk)
    case contentBlockStart(ContentBlockStartChunk)
    case contentBlockDelta(ContentBlockDeltaChunk)
    case contentBlockStop(ContentBlockStopChunk)
    case messageDelta(MessageDeltaChunk)
    case messageStop(MessageStopChunk)
    case ping
    case error(StreamingErrorChunk)
    
    private enum CodingKeys: String, CodingKey {
        case type
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
        case "message_delta":
            let chunk = try MessageDeltaChunk(from: decoder)
            self = .messageDelta(chunk)
        case "message_stop":
            let chunk = try MessageStopChunk(from: decoder)
            self = .messageStop(chunk)
        case "ping":
            self = .ping
        case "error":
            let chunk = try StreamingErrorChunk(from: decoder)
            self = .error(chunk)
        default:
            // Instead of throwing, create an error chunk for unknown types
            let errorChunk = StreamingErrorChunk(
                error: StreamingErrorChunk.ErrorDetail(
                    type: "unknown_chunk_type",
                    message: "Received unknown streaming chunk type: '\(type)'. This may indicate a new API feature or model-specific behavior."
                )
            )
            self = .error(errorChunk)
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
        case .messageDelta(let chunk):
            try chunk.encode(to: encoder)
        case .messageStop(let chunk):
            try chunk.encode(to: encoder)
        case .ping:
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("ping", forKey: .type)
        case .error(let chunk):
            try chunk.encode(to: encoder)
        }
    }
    
    /// The type identifier of this streaming chunk
    public var type: String {
        switch self {
        case .messageStart: return "message_start"
        case .contentBlockStart: return "content_block_start"
        case .contentBlockDelta: return "content_block_delta"
        case .contentBlockStop: return "content_block_stop"
        case .messageDelta: return "message_delta"
        case .messageStop: return "message_stop"
        case .ping: return "ping"
        case .error: return "error"
        }
    }
}

/// Streaming chunk for message start event
public struct MessageStartChunk: Codable, Equatable {
    public let type: String
    public let message: MessageResponse
    
    public init(type: String = "message_start", message: MessageResponse) {
        self.type = type
        self.message = message
    }
}

/// Streaming chunk for content block start event
public struct ContentBlockStartChunk: Codable, Equatable {
    public let type: String
    public let index: Int
    public let contentBlock: ContentBlock
    
    public struct ContentBlock: Codable, Equatable {
        public let type: String
        public let text: String?
        
        public init(type: String, text: String? = nil) {
            self.type = type
            self.text = text
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case index
        case contentBlock = "content_block"
    }
    
    public init(type: String = "content_block_start", index: Int, contentBlock: ContentBlock) {
        self.type = type
        self.index = index
        self.contentBlock = contentBlock
    }
}

/// Streaming chunk for content block delta (incremental text)
public struct ContentBlockDeltaChunk: Codable, Equatable {
    public let type: String
    public let index: Int
    public let delta: Delta
    
    public struct Delta: Codable, Equatable {
        public let type: String
        public let text: String
        
        public init(type: String, text: String) {
            self.type = type
            self.text = text
        }
    }
    
    public init(type: String = "content_block_delta", index: Int, delta: Delta) {
        self.type = type
        self.index = index
        self.delta = delta
    }
}

/// Streaming chunk for content block stop event
public struct ContentBlockStopChunk: Codable, Equatable {
    public let type: String
    public let index: Int
    
    public init(type: String = "content_block_stop", index: Int) {
        self.type = type
        self.index = index
    }
}

/// Streaming chunk for message delta (updates to final Message object)
public struct MessageDeltaChunk: Codable, Equatable {
    public let type: String
    public let delta: Delta
    public let usage: Usage?
    
    public struct Delta: Codable, Equatable {
        public let stopReason: String?
        public let stopSequence: String?
        
        private enum CodingKeys: String, CodingKey {
            case stopReason = "stop_reason"
            case stopSequence = "stop_sequence"
        }
        
        public init(stopReason: String? = nil, stopSequence: String? = nil) {
            self.stopReason = stopReason
            self.stopSequence = stopSequence
        }
    }
    
    public init(type: String = "message_delta", delta: Delta, usage: Usage? = nil) {
        self.type = type
        self.delta = delta
        self.usage = usage
    }
}

/// Streaming chunk for message stop event
public struct MessageStopChunk: Codable, Equatable {
    public let type: String
    
    public init(type: String = "message_stop") {
        self.type = type
    }
}

/// Streaming chunk for error events
public struct StreamingErrorChunk: Codable, Equatable, Error {
    public let type: String
    public let error: ErrorDetail
    
    public struct ErrorDetail: Codable, Equatable {
        public let type: String
        public let message: String
        
        public init(type: String, message: String) {
            self.type = type
            self.message = message
        }
    }
    
    public init(type: String = "error", error: ErrorDetail) {
        self.type = type
        self.error = error
    }
    
    /// Convert to localized description for Error conformance
    public var errorDescription: String? {
        return "\(error.type): \(error.message)"
    }
    
    /// Convert to a string representation
    public var localizedDescription: String {
        return errorDescription ?? "Unknown streaming error"
    }
}

/// AsyncSequence for streaming Anthropic API responses
public struct MessageStream: AsyncSequence {
    public typealias Element = StreamingChunk
    
    private let httpClient: HTTPClient
    private let request: HTTPRequest
    
    init(httpClient: HTTPClient, request: HTTPRequest) {
        self.httpClient = httpClient
        self.request = request
    }
    
    public func makeAsyncIterator() -> MessageStreamIterator {
        MessageStreamIterator(httpClient: httpClient, request: request)
    }
}

/// AsyncIterator for MessageStream with proper SSE parsing and mobile optimization
public struct MessageStreamIterator: AsyncIteratorProtocol {
    public typealias Element = StreamingChunk
    
    private let httpClient: HTTPClient
    private let request: HTTPRequest
    private var urlSessionTask: URLSessionDataTask?
    private var continuation: AsyncThrowingStream<StreamingChunk, Error>.Continuation?
    private var stream: AsyncThrowingStream<StreamingChunk, Error>?
    private var iterator: AsyncThrowingStream<StreamingChunk, Error>.Iterator?
    
    init(httpClient: HTTPClient, request: HTTPRequest) {
        self.httpClient = httpClient
        self.request = request
    }
    
    public mutating func next() async throws -> StreamingChunk? {
        // Initialize the stream on first call
        if iterator == nil {
            try await initializeStream()
        }
        
        return try await iterator?.next()
    }
    
    private mutating func initializeStream() async throws {
        let urlRequest = try request.toURLRequest()
        
        // Create an AsyncThrowingStream for proper streaming
        let (asyncStream, continuation) = AsyncThrowingStream.makeStream(
            of: StreamingChunk.self,
            bufferingPolicy: .bufferingOldest(10) // Mobile memory optimization
        )
        
        self.stream = asyncStream
        self.iterator = asyncStream.makeAsyncIterator()
        self.continuation = continuation
        
        // Create URLSession with custom delegate
        let delegate = StreamingTaskDelegate(continuation: continuation)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        
        // Create URLSessionDataTask for streaming
        let task = session.dataTask(with: urlRequest)
        
        // Start the streaming request
        task.resume()
        self.urlSessionTask = task
    }
}

/// URLSessionTaskDelegate for handling streaming Server-Sent Events
private class StreamingTaskDelegate: NSObject, URLSessionDataDelegate {
    private let continuation: AsyncThrowingStream<StreamingChunk, Error>.Continuation
    private var buffer = Data()
    private let decoder = JSONDecoder()
    
    init(continuation: AsyncThrowingStream<StreamingChunk, Error>.Continuation) {
        self.continuation = continuation
        super.init()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // Check for HTTP errors
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                continuation.finish(throwing: HTTPError.httpError(httpResponse.statusCode))
                completionHandler(.cancel)
                return
            }
        }
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        
        // Process complete Server-Sent Events from buffer
        while let eventData = extractNextSSEEvent() {
            if let chunk = parseSSEEvent(eventData) {
                // Handle error chunks specially - they can be yielded or thrown
                if case .error(_) = chunk {
                    // For parsing errors, we yield them to allow graceful handling
                    // For critical errors, we might want to throw
                    continuation.yield(chunk)
                } else {
                    continuation.yield(chunk)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation.finish(throwing: error)
        } else {
            continuation.finish()
        }
    }
    
    private func extractNextSSEEvent() -> Data? {
        // Look for double newline which indicates end of SSE event
        // Handle both \n\n and \r\n\r\n patterns
        let delimiterLF = "\n\n".data(using: .utf8)!
        let delimiterCRLF = "\r\n\r\n".data(using: .utf8)!
        
        // Check for \r\n\r\n first (Windows-style)
        if let range = buffer.range(of: delimiterCRLF) {
            let eventData = buffer.subdata(in: 0..<range.lowerBound)
            buffer.removeSubrange(0..<range.upperBound)
            return eventData
        }
        
        // Check for \n\n (Unix-style)
        if let range = buffer.range(of: delimiterLF) {
            let eventData = buffer.subdata(in: 0..<range.lowerBound)
            buffer.removeSubrange(0..<range.upperBound)
            return eventData
        }
        
        return nil
    }
    
    private func parseSSEEvent(_ eventData: Data) -> StreamingChunk? {
        guard let eventString = String(data: eventData, encoding: .utf8) else {
            // Create error chunk for invalid UTF-8 encoding
            let errorChunk = StreamingErrorChunk(
                error: StreamingErrorChunk.ErrorDetail(
                    type: "encoding_error",
                    message: "SSE event data contains invalid UTF-8 encoding"
                )
            )
            return .error(errorChunk)
        }
        
        let lines = eventString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var dataLines: [String] = []
        var eventType: String?
        
        for line in lines.filter({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            if line.hasPrefix("data: ") {
                let dataContent = String(line.dropFirst(6)) // Remove "data: "
                dataLines.append(dataContent)
            } else if line.hasPrefix("event: ") {
                eventType = String(line.dropFirst(7)) // Remove "event: "
            }
            // Ignore other SSE fields like "id:" and "retry:"
        }
        
        guard !dataLines.isEmpty else {
            // This is normal for ping events or empty chunks
            return nil
        }
        
        // Combine all data lines
        let combinedData = dataLines.joined(separator: "\n")
        
        // Handle special event types
        if eventType == "ping" || combinedData.trimmingCharacters(in: .whitespaces).isEmpty {
            return .ping
        }
        
        guard let jsonData = combinedData.data(using: .utf8) else {
            let errorChunk = StreamingErrorChunk(
                error: StreamingErrorChunk.ErrorDetail(
                    type: "encoding_error",
                    message: "Failed to convert combined data to UTF-8"
                )
            )
            return .error(errorChunk)
        }
        
        // Parse JSON data to StreamingChunk with enhanced error handling
        do {
            let chunk = try decoder.decode(StreamingChunk.self, from: jsonData)
            return chunk
        } catch let decodingError as DecodingError {
            // Enhanced error reporting for debugging
            var errorMessage = "Failed to parse streaming chunk: "
            
            switch decodingError {
            case .dataCorrupted(let context):
                errorMessage += "Data corrupted at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)"
            case .keyNotFound(let key, let context):
                errorMessage += "Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            case .typeMismatch(let type, let context):
                errorMessage += "Type mismatch for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                errorMessage += "Value not found for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            @unknown default:
                errorMessage += decodingError.localizedDescription
            }
            
            // Include raw data for debugging (truncated to avoid huge logs)
            let rawDataPreview = String(combinedData.prefix(200))
            errorMessage += " | Raw data preview: \(rawDataPreview)"
            
            let errorChunk = StreamingErrorChunk(
                error: StreamingErrorChunk.ErrorDetail(
                    type: "parsing_error",
                    message: errorMessage
                )
            )
            return .error(errorChunk)
        } catch {
            // Generic error fallback
            let errorChunk = StreamingErrorChunk(
                error: StreamingErrorChunk.ErrorDetail(
                    type: "parsing_error",
                    message: "Failed to parse streaming chunk: \(error.localizedDescription) | Raw data: \(String(combinedData.prefix(200)))"
                )
            )
            return .error(errorChunk)
        }
    }
}