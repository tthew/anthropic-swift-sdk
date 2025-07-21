# Error Handling Guide

The Anthropic Swift SDK provides comprehensive error handling to help you build robust applications. This guide covers all error types, common scenarios, and best practices for error handling.

## Error Types

### AnthropicError

SDK-specific errors for client configuration and parameter validation:

```swift
public enum AnthropicError: Error, LocalizedError {
    case invalidAPIKey          // API key format is incorrect
    case emptyAPIKey           // API key is empty or missing
    case missingEnvironmentKey // ANTHROPIC_API_KEY env var not set
    case invalidParameter(String) // Parameter validation failed
}
```

**Example handling:**
```swift
do {
    let client = try AnthropicClient(apiKey: apiKey)
} catch AnthropicError.invalidAPIKey {
    print("API key must start with 'sk-ant-'")
} catch AnthropicError.emptyAPIKey {
    print("Please provide an API key")
} catch AnthropicError.missingEnvironmentKey {
    print("Set ANTHROPIC_API_KEY environment variable")
} catch AnthropicError.invalidParameter(let message) {
    print("Invalid parameter: \(message)")
}
```

### HTTPError

Network and API response errors:

```swift
public enum HTTPError: Error, LocalizedError {
    case invalidResponse        // Response format is invalid
    case unauthorized          // 401: API key is invalid/expired
    case forbidden            // 403: Access denied
    case notFound             // 404: Resource not found
    case rateLimited          // 429: Rate limit exceeded
    case serverError(Int)     // 5xx: Server-side errors
    case networkError(Error)  // Network connectivity issues
}
```

**Example handling:**
```swift
do {
    let response = try await client.sendMessage("Hello, Claude!")
} catch HTTPError.unauthorized {
    print("API key is invalid or expired")
} catch HTTPError.rateLimited {
    print("Rate limit exceeded - implement retry logic")
} catch HTTPError.serverError(let statusCode) {
    print("Server error: \(statusCode) - try again later")
} catch HTTPError.networkError(let error) {
    print("Network issue: \(error.localizedDescription)")
}
```

## Common Error Scenarios

### 1. Authentication Errors

```swift
// Invalid API key format
do {
    let client = try AnthropicClient(apiKey: "invalid-key")
} catch AnthropicError.invalidAPIKey {
    // Handle: Prompt user for correct API key format
    showAPIKeyFormatError()
}

// Expired or revoked API key
do {
    let response = try await client.sendMessage("Test")
} catch HTTPError.unauthorized {
    // Handle: Refresh API key or re-authenticate
    await refreshAPIKey()
}
```

### 2. Rate Limiting

Implement exponential backoff for rate limits:

```swift
func sendWithRetry(_ message: String, maxAttempts: Int = 3) async throws -> MessageResponse {
    for attempt in 1...maxAttempts {
        do {
            return try await client.sendMessage(message)
        } catch HTTPError.rateLimited {
            if attempt < maxAttempts {
                let delay = min(pow(2.0, Double(attempt)), 60.0) // Max 60 seconds
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                continue
            }
            throw HTTPError.rateLimited
        }
    }
    fatalError("Should not reach here")
}
```

### 3. Parameter Validation

```swift
// Handle parameter validation errors
do {
    let request = CreateMessageRequest(
        model: .claude3_5Sonnet,
        messages: [.user("Hello")],
        maxTokens: 5000 // Too high
    )
    try request.validate()
} catch AnthropicError.invalidParameter(let message) {
    print("Parameter error: \(message)")
    // Adjust parameters and retry
}
```

### 4. Batch Operation Errors

```swift
do {
    let batch = try await client.batches.create(batchRequest)
} catch AnthropicError.invalidParameter(let message) where message.contains("duplicate") {
    print("Duplicate custom IDs found - ensure unique IDs")
    // Fix duplicate IDs and retry
} catch AnthropicError.invalidParameter(let message) where message.contains("maximum") {
    print("Too many requests in batch - split into smaller batches")
    // Split batch and retry
}
```

### 5. File Upload Errors

```swift
do {
    let uploadResponse = try await client.files.upload(fileRequest)
} catch AnthropicError.invalidParameter(let message) where message.contains("size") {
    print("File too large - compress or split file")
    // Handle file size limit
} catch AnthropicError.invalidParameter(let message) where message.contains("content type") {
    print("Unsupported file type")
    // Convert to supported format
}
```

## Best Practices

### 1. Comprehensive Error Handling

Always handle all possible error cases:

```swift
func handleAPICall() async {
    do {
        let response = try await client.sendMessage("Hello, Claude!")
        processResponse(response)
    } catch AnthropicError.invalidAPIKey {
        showAPIKeyError()
    } catch AnthropicError.invalidParameter(let message) {
        showParameterError(message)
    } catch HTTPError.unauthorized {
        handleAuthenticationError()
    } catch HTTPError.rateLimited {
        scheduleRetry()
    } catch HTTPError.serverError(let code) {
        handleServerError(code)
    } catch HTTPError.networkError(let error) {
        handleNetworkError(error)
    } catch {
        handleUnexpectedError(error)
    }
}
```

### 2. Retry Strategy Implementation

```swift
actor RetryManager {
    private let maxAttempts: Int
    private let baseDelay: TimeInterval
    
    init(maxAttempts: Int = 3, baseDelay: TimeInterval = 1.0) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
    }
    
    func executeWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch HTTPError.rateLimited, HTTPError.serverError {
                lastError = error
                if attempt < maxAttempts {
                    let delay = baseDelay * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
            } catch {
                throw error // Don't retry non-retryable errors
            }
        }
        
        throw lastError ?? HTTPError.serverError(500)
    }
}
```

### 3. Circuit Breaker Pattern

```swift
actor CircuitBreaker {
    enum State {
        case closed, open, halfOpen
    }
    
    private var state = State.closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    private let failureThreshold = 5
    private let timeout: TimeInterval = 60
    
    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        switch state {
        case .open:
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > timeout {
                state = .halfOpen
            } else {
                throw HTTPError.serverError(503) // Circuit breaker open
            }
        case .halfOpen, .closed:
            break
        }
        
        do {
            let result = try await operation()
            recordSuccess()
            return result
        } catch {
            recordFailure()
            throw error
        }
    }
    
    private func recordSuccess() {
        failureCount = 0
        state = .closed
    }
    
    private func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()
        
        if failureCount >= failureThreshold {
            state = .open
        }
    }
}
```

### 4. Error Recovery Strategies

```swift
class ErrorRecoveryManager {
    private let client: AnthropicClient
    private let retryManager = RetryManager()
    
    init(client: AnthropicClient) {
        self.client = client
    }
    
    func sendMessageWithRecovery(_ message: String) async throws -> MessageResponse {
        return try await retryManager.executeWithRetry {
            do {
                return try await client.sendMessage(message)
            } catch HTTPError.rateLimited {
                // Implement exponential backoff
                throw HTTPError.rateLimited
            } catch HTTPError.serverError(let code) where code >= 500 {
                // Retry server errors
                throw HTTPError.serverError(code)
            } catch HTTPError.unauthorized {
                // Try to refresh API key
                try await refreshAPIKey()
                return try await client.sendMessage(message)
            }
        }
    }
    
    private func refreshAPIKey() async throws {
        // Implement API key refresh logic
    }
}
```

### 5. Error Logging and Monitoring

```swift
struct ErrorTracker {
    static func logError(_ error: Error, context: String) {
        let errorInfo = [
            "context": context,
            "error_type": String(describing: type(of: error)),
            "error_description": error.localizedDescription,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Log to your analytics service
        Analytics.track("sdk_error", properties: errorInfo)
        
        // Local logging for debugging
        print("SDK Error [\(context)]: \(error)")
    }
}

// Usage
do {
    let response = try await client.sendMessage("Hello")
} catch {
    ErrorTracker.logError(error, context: "send_message")
    throw error
}
```

## Error Recovery Examples

### Streaming Error Recovery

```swift
func processStreamWithRecovery(_ stream: MessageStream) async {
    do {
        for try await chunk in stream {
            processChunk(chunk)
        }
    } catch HTTPError.networkError {
        // Network issue - try to reconnect
        print("Network error in stream - attempting reconnection...")
        try await reconnectStream()
    } catch HTTPError.rateLimited {
        // Rate limited - wait and resume
        print("Stream rate limited - waiting before resume...")
        try await Task.sleep(nanoseconds: 5_000_000_000)
        try await resumeStream()
    } catch {
        print("Stream error: \(error)")
        // Handle other stream errors
    }
}
```

### Batch Error Recovery

```swift
func processBatchWithErrorHandling(_ requests: [BatchRequest]) async throws -> [BatchResult] {
    do {
        let batchRequest = CreateBatchRequest(requests: requests)
        let batch = try await client.batches.create(batchRequest)
        
        return try await waitForBatchCompletion(batch.id)
    } catch AnthropicError.invalidParameter(let message) where message.contains("maximum") {
        // Split large batch into smaller chunks
        let chunkSize = 1000
        var allResults: [BatchResult] = []
        
        for chunk in requests.chunked(into: chunkSize) {
            let chunkBatch = try await client.batches.create(
                CreateBatchRequest(requests: chunk)
            )
            let chunkResults = try await waitForBatchCompletion(chunkBatch.id)
            allResults.append(contentsOf: chunkResults)
        }
        
        return allResults
    }
}
```

## Testing Error Conditions

Create mock scenarios to test error handling:

```swift
class MockHTTPClient: HTTPClient {
    var shouldReturnError: HTTPError?
    
    override func send<T: Decodable>(_ request: HTTPRequest) async throws -> T {
        if let error = shouldReturnError {
            throw error
        }
        return try await super.send(request)
    }
}

// Test rate limiting
func testRateLimitHandling() async throws {
    let mockClient = MockHTTPClient()
    mockClient.shouldReturnError = .rateLimited
    
    let client = AnthropicClient(httpClient: mockClient, apiKey: "sk-ant-test")
    
    do {
        _ = try await client.sendMessage("Test")
        XCTFail("Should have thrown rate limit error")
    } catch HTTPError.rateLimited {
        // Expected - test retry logic here
    }
}
```

## Summary

Effective error handling in the Anthropic Swift SDK involves:

1. **Catch specific error types** rather than generic errors
2. **Implement retry logic** for transient failures
3. **Use circuit breakers** for protecting against cascading failures
4. **Log errors** for monitoring and debugging
5. **Provide meaningful feedback** to users
6. **Test error conditions** thoroughly
7. **Implement graceful degradation** where possible

By following these patterns, your applications will be more resilient and provide better user experiences even when errors occur.