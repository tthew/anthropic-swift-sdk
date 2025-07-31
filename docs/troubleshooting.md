---
layout: page
title: Troubleshooting
permalink: /troubleshooting/
---

# Troubleshooting Guide

Common issues and solutions when using the Anthropic Swift SDK.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Authentication Problems](#authentication-problems)
- [API Errors](#api-errors)
- [Streaming Issues](#streaming-issues)
- [Performance Problems](#performance-problems)
- [Platform-Specific Issues](#platform-specific-issues)
- [Debugging Tips](#debugging-tips)
- [Common Patterns](#common-patterns)

## Installation Issues

### Swift Package Manager Resolution Fails

**Problem**: Xcode fails to resolve the package dependency.

**Solutions**:

1. **Clear Xcode caches**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

2. **Reset Swift Package Manager**:
   ```bash
   swift package reset
   swift package clean
   ```

3. **Force package resolution**:
   ```bash
   swift package resolve --force-resolved-versions
   ```

4. **Update to latest version**:
   - In Xcode: File → Package Dependencies → Select package → Update Package
   - Or specify exact version in Package.swift:
   ```swift
   .package(url: "https://github.com/tthew/anthropic-swift-sdk", from: "1.1.3")
   ```

### Build Errors with Older Xcode Versions

**Problem**: Build fails with Swift compiler errors on older Xcode versions.

**Solution**: Ensure you're using compatible versions:
- **Xcode 14.0+** required
- **Swift 5.9+** required
- **iOS 15.0+ / macOS 12.0+** deployment targets

Update your project's deployment target:
```swift
// Package.swift
platforms: [
    .iOS(.v15),
    .macOS(.v12)
]
```

### Missing Claude 4 Models

**Problem**: Claude 4 models (`.claude4Opus`, `.claude4Sonnet`) not available.

**Solution**: Update to SDK version 1.1.3 or later:

```swift
import AnthropicSDK

// Check SDK version
SDKVersion.printVersion()

// Should show:
// Anthropic Swift SDK v1.1.3
// Claude 4 Support: ✅ Available
```

If still missing, clear caches and update:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
# In Xcode: File → Package Dependencies → Update Package
```

## Authentication Problems

### "Missing API Key" Error

**Problem**: `AnthropicError.missingEnvironmentKey` when initializing client.

**Solutions**:

1. **Set environment variable**:
   ```bash
   export ANTHROPIC_API_KEY="sk-ant-your-api-key"
   ```

2. **For Xcode projects**, add to scheme:
   - Product → Scheme → Edit Scheme...
   - Run → Environment Variables
   - Add `ANTHROPIC_API_KEY` with your key

3. **Use direct initialization**:
   ```swift
   let client = try AnthropicClient(apiKey: "sk-ant-your-api-key")
   ```

### "Invalid API Key" Error

**Problem**: `AnthropicError.invalidAPIKey` when initializing client.

**Cause**: API key doesn't start with `sk-ant-` prefix.

**Solution**: Verify your API key format:
```swift
// ❌ Wrong
let client = try AnthropicClient(apiKey: "your-api-key")

// ✅ Correct
let client = try AnthropicClient(apiKey: "sk-ant-api03-...")
```

Get a valid API key from [console.anthropic.com](https://console.anthropic.com).

### 401 Unauthorized Errors

**Problem**: `HTTPError.unauthorized` when making API calls.

**Causes and Solutions**:

1. **Expired or revoked API key**:
   - Generate a new API key in the Anthropic Console
   - Update your application with the new key

2. **Incorrect API key**:
   - Double-check the key value
   - Ensure no extra spaces or characters

3. **Rate limiting**:
   - Check if you've exceeded your usage limits
   - Implement exponential backoff retry logic

```swift
func sendWithRetry(message: String, maxAttempts: Int = 3) async throws -> MessageResponse {
    for attempt in 1...maxAttempts {
        do {
            return try await client.sendMessage(message)
        } catch HTTPError.unauthorized {
            if attempt < maxAttempts {
                let delay = pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                continue
            }
            throw HTTPError.unauthorized
        }
    }
    fatalError("Should not reach here")
}
```

## API Errors

### Rate Limiting (429 Errors)

**Problem**: `HTTPError.rateLimited` errors during high-volume usage.

**Solutions**:

1. **Implement exponential backoff**:
   ```swift
   do {
       let response = try await client.sendMessage("Hello")
   } catch HTTPError.rateLimited {
       // Wait before retrying
       try await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
       // Retry the request
   }
   ```

2. **Use batch operations** for multiple requests:
   ```swift
   // Instead of multiple individual requests
   let batchRequests = messages.map { message in
       BatchRequest(customId: message.id, method: .POST, url: "/v1/messages",
                   body: CreateMessageRequest(model: .claude3_5Sonnet, messages: [message]))
   }
   let batch = try await client.batches.create(CreateBatchRequest(requests: batchRequests))
   ```

3. **Configure request throttling**:
   ```swift
   let config = ClientConfiguration(
       maxConcurrentRequests: 3, // Reduce concurrent requests
       enableRetry: true,
       maxRetryAttempts: 5,
       retryBaseDelay: 2.0 // Longer delays between retries
   )
   let client = try AnthropicClient(apiKey: "your-key", configuration: config)
   ```

### Server Errors (5xx)

**Problem**: `HTTPError.serverError` with status codes 500, 502, 503, 504.

**Solutions**:

1. **Implement retry logic with circuit breaker**:
   ```swift
   class CircuitBreaker {
       private var failureCount = 0
       private var lastFailureTime: Date?
       private let failureThreshold = 5
       private let recoveryTimeout: TimeInterval = 60
       
       func canMakeRequest() -> Bool {
           if failureCount < failureThreshold {
               return true
           }
           
           if let lastFailure = lastFailureTime,
              Date().timeIntervalSince(lastFailure) > recoveryTimeout {
               failureCount = 0
               return true
           }
           
           return false
       }
       
       func recordSuccess() {
           failureCount = 0
           lastFailureTime = nil
       }
       
       func recordFailure() {
           failureCount += 1
           lastFailureTime = Date()
       }
   }
   ```

2. **Use server configuration** for backend applications:
   ```swift
   let client = try AnthropicClient(
       apiKey: "your-key",
       configuration: .server // Higher timeouts and more aggressive retries
   )
   ```

### Token Limit Exceeded

**Problem**: Requests fail due to exceeding model token limits.

**Solutions**:

1. **Check token usage before sending**:
   ```swift
   func estimateTokens(_ text: String) -> Int {
       // Rough estimation: ~4 characters per token
       return text.count / 4
   }
   
   let message = "Your very long message..."
   let estimatedTokens = estimateTokens(message)
   
   if estimatedTokens > 180000 { // Leave room for response
       // Split message or use summarization
       print("Message too long, estimated \(estimatedTokens) tokens")
   }
   ```

2. **Use appropriate models for content length**:
   ```swift
   let longContent = "..."
   let model: ClaudeModel = longContent.count > 50000 ? .claude4Sonnet : .claude3_5Haiku
   ```

3. **Implement content chunking**:
   ```swift
   func processLongContent(_ content: String) async throws -> [String] {
       let chunkSize = 50000 // Characters per chunk
       let chunks = content.chunked(into: chunkSize)
       var results: [String] = []
       
       for chunk in chunks {
           let response = try await client.sendMessage(
               "Summarize this section: \(chunk)",
               model: .claude3_5Sonnet,
               maxTokens: 500
           )
           if let summary = response.content.first?.text {
               results.append(summary)
           }
       }
       
       return results
   }
   
   extension String {
       func chunked(into size: Int) -> [String] {
           return stride(from: 0, to: count, by: size).map {
               String(self[index(startIndex, offsetBy: $0)..<index(startIndex, offsetBy: min($0 + size, count))])
           }
       }
   }
   ```

## Streaming Issues

### Parsing Errors with Claude 3.5 Haiku

**Problem**: Streaming fails with parsing errors when using Claude 3.5 Haiku.

**Cause**: Enhanced parsing in v1.1.3+ may encounter unknown chunk types from API updates.

**Solutions**:

1. **Enhanced error handling** (v1.1.3+):
   ```swift
   let stream = try await client.streamMessage("Your prompt", model: .claude3_5Haiku)
   
   for try await chunk in stream {
       switch chunk {
       case .error(let streamError):
           print("Stream error: \(streamError.localizedDescription)")
           
           switch streamError.error.type {
           case "parsing_error":
               print("Parsing error - continuing...")
               continue // Continue processing other chunks
           case "unknown_chunk_type":
               print("Unknown chunk type - may need SDK update")
               continue
           default:
               break // Handle other errors
           }
       default:
           // Process normal chunks
           break
       }
   }
   ```

2. **Fallback to non-streaming**:
   ```swift
   do {
       let stream = try await client.streamMessage("Your prompt", model: .claude3_5Haiku)
       // Process stream...
   } catch {
       // Fall back to non-streaming
       print("Streaming failed, falling back to regular request")
       let response = try await client.sendMessage("Your prompt", model: .claude3_5Haiku)
       print(response.content.first?.text ?? "")
   }
   ```

3. **Use alternative models**:
   ```swift
   // Claude 3.5 Sonnet has more stable streaming
   let stream = try await client.streamMessage("Your prompt", model: .claude3_5Sonnet)
   ```

### Stream Interruption

**Problem**: Streaming stops unexpectedly without completing.

**Solutions**:

1. **Implement stream timeout**:
   ```swift
   func streamWithTimeout(prompt: String, timeout: TimeInterval = 300) async throws {
       let stream = try await client.streamMessage(prompt)
       
       let timeoutTask = Task {
           try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
           throw TimeoutError()
       }
       
       let streamTask = Task {
           for try await chunk in stream {
               // Process chunks
           }
       }
       
       do {
           _ = try await streamTask.value
           timeoutTask.cancel()
       } catch {
           timeoutTask.cancel()
           streamTask.cancel()
           throw error
       }
   }
   ```

2. **Monitor stream health**:
   ```swift
   var lastChunkTime = Date()
   let healthCheckInterval: TimeInterval = 30
   
   for try await chunk in stream {
       lastChunkTime = Date()
       
       // Process chunk...
       
       // Check if stream is stalled
       if Date().timeIntervalSince(lastChunkTime) > healthCheckInterval {
           print("Stream appears stalled, considering restart")
           break
       }
   }
   ```

### Memory Issues with Long Streams

**Problem**: Memory usage grows during long streaming sessions.

**Solutions**:

1. **Process chunks immediately**:
   ```swift
   var buffer = ""
   let maxBufferSize = 1000
   
   for try await chunk in stream {
       if case .contentBlockDelta(let delta) = chunk,
          case .textDelta(let text) = delta.delta {
           buffer += text
           
           // Process and clear buffer regularly
           if buffer.count > maxBufferSize {
               await processText(buffer)
               buffer = "" // Clear buffer to free memory
           }
       }
   }
   
   // Process remaining buffer
   if !buffer.isEmpty {
       await processText(buffer)
   }
   ```

2. **Use weak references in closures**:
   ```swift
   Task { [weak self] in
       guard let self = self else { return }
       // Stream processing...
   }
   ```

## Performance Problems

### Slow Response Times

**Problem**: Requests take longer than expected to complete.

**Solutions**:

1. **Use appropriate model for task**:
   ```swift
   // Fast models for simple tasks
   let quickResponse = try await client.sendMessage(
       "What's 2+2?",
       model: .claude3_5Haiku, // Fastest
       maxTokens: 10
   )
   
   // Powerful models for complex tasks
   let complexResponse = try await client.sendMessage(
       "Analyze this complex dataset...",
       model: .claude4Sonnet, // Most capable
       maxTokens: 2000
   )
   ```

2. **Optimize request parameters**:
   ```swift
   let response = try await client.sendMessage(
       "Brief answer only: What is Swift?",
       model: .claude3_5Haiku,
       maxTokens: 50 // Limit response length for speed
   )
   ```

3. **Use streaming for long responses**:
   ```swift
   // Get immediate feedback instead of waiting for complete response
   let stream = try await client.streamMessage("Write a long story...")
   ```

4. **Configure timeouts appropriately**:
   ```swift
   let config = ClientConfiguration(
       connectionTimeout: 30,    // 30 seconds for connection
       resourceTimeout: 120,     // 2 minutes for response
       maxConcurrentRequests: 8  // Allow more parallel requests
   )
   ```

### High Memory Usage

**Problem**: Application memory usage grows excessively.

**Solutions**:

1. **Use mobile configuration**:
   ```swift
   let client = try AnthropicClient(
       apiKey: "your-key",
       configuration: .mobile // Optimized for iOS/mobile constraints
   )
   ```

2. **Limit concurrent requests**:
   ```swift
   let config = ClientConfiguration(
       maxConcurrentRequests: 3, // Reduce for memory-constrained devices
       enableCaching: false      // Disable caching if memory is tight
   )
   ```

3. **Process large responses in chunks**:
   ```swift
   // Instead of storing entire response
   for try await chunk in stream {
       await processChunkImmediately(chunk)
       // Don't accumulate all chunks in memory
   }
   ```

### Network Connectivity Issues

**Problem**: Requests fail due to poor network conditions.

**Solutions**:

1. **Implement network monitoring**:
   ```swift
   import Network
   
   class NetworkMonitor: ObservableObject {
       private let monitor = NWPathMonitor()
       @Published var isConnected = false
       
       init() {
           monitor.pathUpdateHandler = { path in
               DispatchQueue.main.async {
                   self.isConnected = path.status == .satisfied
               }
           }
           let queue = DispatchQueue(label: "NetworkMonitor")
           monitor.start(queue: queue)
       }
   }
   ```

2. **Configure for poor connectivity**:
   ```swift
   let config = ClientConfiguration(
       connectionTimeout: 60,    // Longer timeout for slow connections
       enableRetry: true,
       maxRetryAttempts: 5,
       retryBaseDelay: 3.0      // Longer delays between retries
   )
   ```

3. **Queue requests for offline scenarios**:
   ```swift
   class OfflineRequestQueue {
       private var pendingRequests: [(String, ClaudeModel)] = []
       
       func queueRequest(message: String, model: ClaudeModel) {
           pendingRequests.append((message, model))
       }
       
       func processPendingRequests() async {
           for (message, model) in pendingRequests {
               do {
                   _ = try await client.sendMessage(message, model: model)
                   // Remove from queue on success
               } catch {
                   // Keep in queue for retry
                   break
               }
           }
       }
   }
   ```

## Platform-Specific Issues

### iOS Simulator Issues

**Problem**: SDK doesn't work properly in iOS Simulator.

**Solutions**:

1. **Use device instead of simulator** for network-intensive testing
2. **Check simulator network settings**:
   - Device → Erase All Content and Settings
   - Try different simulator versions

3. **Test on physical device**:
   ```swift
   #if targetEnvironment(simulator)
   print("Running in simulator - some network features may be limited")
   #endif
   ```

### macOS Sandbox Restrictions

**Problem**: Network requests fail in sandboxed macOS apps.

**Solution**: Enable network access in entitlements:
```xml
<!-- YourApp.entitlements -->
<dict>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
```

### Background App Refresh

**Problem**: Requests fail when app is backgrounded on iOS.

**Solutions**:

1. **Use background tasks**:
   ```swift
   import BackgroundTasks
   
   func scheduleBackgroundRefresh() {
       let request = BGAppRefreshTaskRequest(identifier: "com.yourapp.refresh")
       request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
       
       try? BGTaskScheduler.shared.submit(request)
   }
   ```

2. **Complete requests before backgrounding**:
   ```swift
   func sceneDidEnterBackground(_ scene: UIScene) {
       // Cancel any ongoing streams
       streamTask?.cancel()
       
       // Complete any critical requests
       Task {
           await completeEssentialRequests()
       }
   }
   ```

## Debugging Tips

### Enable Detailed Logging

**Problem**: Hard to diagnose issues without proper logging.

**Solution**: Implement comprehensive logging:

```swift
import os.log

extension AnthropicClient {
    func sendMessageWithLogging(_ text: String) async throws -> MessageResponse {
        let logger = Logger(subsystem: "com.yourapp.anthropic", category: "api")
        
        logger.info("Sending message: \(text.prefix(50))...")
        let startTime = Date()
        
        do {
            let response = try await sendMessage(text)
            let duration = Date().timeIntervalSince(startTime)
            
            logger.info("Request completed in \(duration)s, tokens: \(response.usage.outputTokens)")
            return response
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.error("Request failed after \(duration)s: \(error.localizedDescription)")
            throw error
        }
    }
}
```

### Network Request Inspection

**Problem**: Need to inspect network traffic for debugging.

**Solutions**:

1. **Use Charles Proxy or similar tools** to intercept HTTPS traffic
2. **Add request/response logging**:
   ```swift
   // In HTTPClient implementation
   private func logRequest(_ request: URLRequest) {
       print("🔵 Request: \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
       if let body = request.httpBody {
           print("📤 Body: \(String(data: body, encoding: .utf8) ?? "")")
       }
   }
   
   private func logResponse(_ response: HTTPURLResponse, data: Data) {
       print("🟢 Response: \(response.statusCode)")
       print("📥 Data: \(String(data: data, encoding: .utf8) ?? "")")
   }
   ```

### Memory Debugging

**Problem**: Memory leaks or excessive memory usage.

**Solutions**:

1. **Use Xcode Instruments**:
   - Product → Profile → Leaks
   - Product → Profile → Allocations

2. **Add memory monitoring**:
   ```swift
   func logMemoryUsage() {
       let info = mach_task_basic_info()
       var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
       
       let kerr = withUnsafeMutablePointer(to: &info) {
           $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
               task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
           }
       }
       
       if kerr == KERN_SUCCESS {
           let memoryUsageMB = Double(info.resident_size) / 1024.0 / 1024.0
           print("Memory usage: \(String(format: "%.2f", memoryUsageMB)) MB")
       }
   }
   ```

## Common Patterns

### Error Recovery Pattern

```swift
func robustAPICall(message: String, maxAttempts: Int = 3) async throws -> MessageResponse {
    var lastError: Error?
    
    for attempt in 1...maxAttempts {
        do {
            return try await client.sendMessage(message)
            
        } catch HTTPError.rateLimited {
            // Exponential backoff for rate limiting
            let delay = min(pow(2.0, Double(attempt)), 60.0)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            lastError = HTTPError.rateLimited
            
        } catch HTTPError.serverError {
            // Retry server errors
            try await Task.sleep(nanoseconds: UInt64(attempt * 2_000_000_000))
            lastError = HTTPError.serverError(500)
            
        } catch {
            // Don't retry client errors
            throw error
        }
    }
    
    throw lastError ?? AnthropicError.invalidParameter("Max attempts exceeded")
}
```

### Graceful Degradation Pattern

```swift
func getResponseWithFallback(message: String) async -> String {
    // Try primary approach
    do {
        let response = try await client.sendMessage(message, model: .claude4Sonnet)
        return response.content.first?.text ?? "No response"
        
    } catch HTTPError.rateLimited {
        // Fall back to lighter model
        do {
            let response = try await client.sendMessage(message, model: .claude3_5Haiku)
            return response.content.first?.text ?? "No response"
        } catch {
            return "Service temporarily unavailable. Please try again later."
        }
        
    } catch {
        return "Unable to process request at this time."
    }
}
```

### Request Batching Pattern

```swift
class RequestBatcher {
    private var pendingRequests: [(String, CheckedContinuation<String, Error>)] = []
    private let batchSize = 10
    private let batchTimeout: TimeInterval = 5.0
    
    func queueRequest(_ message: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests.append((message, continuation))
            
            if pendingRequests.count >= batchSize {
                Task { await processBatch() }
            } else {
                // Process batch after timeout
                Task {
                    try await Task.sleep(nanoseconds: UInt64(batchTimeout * 1_000_000_000))
                    await processBatch()
                }
            }
        }
    }
    
    private func processBatch() async {
        guard !pendingRequests.isEmpty else { return }
        
        let batch = pendingRequests
        pendingRequests.removeAll()
        
        let batchRequests = batch.enumerated().map { index, request in
            BatchRequest(
                customId: "request_\(index)",
                method: .POST,
                url: "/v1/messages",
                body: CreateMessageRequest(
                    model: .claude3_5Sonnet,
                    messages: [.user(request.0)],
                    maxTokens: 500
                )
            )
        }
        
        do {
            let batchResponse = try await client.batches.create(
                CreateBatchRequest(requests: batchRequests)
            )
            
            // Wait for completion and return results
            // ... implementation details ...
            
        } catch {
            // Fail all pending requests
            for (_, continuation) in batch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

## Getting Help

If you're still experiencing issues:

1. **Check the [GitHub Issues](https://github.com/tthew/anthropic-swift-sdk/issues)** for similar problems
2. **Review the [Examples](examples.html)** for usage patterns
3. **Check the [API Reference](api-reference.html)** for detailed documentation
4. **Create a new issue** with:
   - SDK version (`SDKVersion.printVersion()`)
   - Platform and OS version
   - Minimal reproducible example
   - Full error messages and stack traces
   - Network conditions and configuration

For quick questions, check the [GitHub Discussions](https://github.com/tthew/anthropic-swift-sdk/discussions) where the community can help.