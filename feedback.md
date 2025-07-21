# Bug Report: Streaming API Parsing Error with Claude 3.5 Haiku

## **Issue Summary**
The Anthropic Swift SDK v1.1.1 throws a streaming parsing error when using `client.streamMessage()` with the `claude-3-5-haiku-20241022` model, while non-streaming calls work perfectly.

## **Error Details**
```
StreamingErrorChunk(
  type: "error", 
  error: StreamingErrorChunk.ErrorDetail(
    type: "parsing_error", 
    message: "Failed to parse streaming chunk: The data couldn't be read because it isn't in the correct format."
  )
)
```

## **Environment**
- **SDK Version**: v1.1.1 
- **Platform**: iOS 18.5+ (Swift 5.0)
- **Model**: `claude-3-5-haiku-20241022` (fails), `claude-opus-4-20250514` (works)
- **API**: Vision works for streaming, text-only streaming fails

## **Reproduction Steps**
1. Initialize AnthropicClient with valid API key
2. Use `client.streamMessage()` with `claude-3-5-haiku-20241022`
3. Iterate through stream chunks
4. Error occurs when processing streaming chunks

## **Working vs Failing Scenarios**

**✅ Works:**
- Non-streaming calls to `claude-3-5-haiku-20241022`
- Streaming calls to `claude-opus-4-20250514` (vision model)
- All non-streaming API operations

**❌ Fails:**
- Streaming calls to `claude-3-5-haiku-20241022`
- Any model that produces chunks the parser can't handle

## **Code Pattern**
```swift
let stream = try await client.streamMessage(
    prompt,
    model: .claude3_5Haiku,  // Fails here
    maxTokens: 2048
)

for try await chunk in stream {
    switch chunk {
    case .contentBlockDelta(let delta):
        // Never reached due to parsing error
    case .error(let streamError):
        // This is where the error surfaces
    }
}
```

## **Root Cause Analysis**
The issue appears to be in the SDK's streaming chunk parser, not in the API response itself. The error suggests that:

1. **Chunk Format Mismatch**: Different models may send streaming chunks in slightly different formats
2. **Parser Rigidity**: The SDK parser may be too strict about expected chunk structure
3. **Model-Specific Streaming**: Some models may have different streaming behaviors

## **Suggested Investigation Areas**

1. **Chunk Format Validation**: Compare raw streaming responses between working models (opus-4) and failing models (haiku)

2. **Parser Error Handling**: The current parser throws parsing errors instead of gracefully handling unexpected chunk formats

3. **Model-Specific Streaming Support**: Document which models support streaming vs which require fallback to non-streaming

4. **Error Type Issues**: `StreamingErrorChunk` doesn't conform to Swift's `Error` protocol, making error handling difficult:
   ```swift
   // This fails to compile:
   continuation.finish(throwing: streamError) 
   
   // Requires workaround:
   continuation.finish(throwing: APIError.invalidResponse)
   ```

## **Recommended Fixes**

1. **Improve Parser Resilience**: Make the streaming parser more tolerant of minor format variations
2. **Add Error Protocol Conformance**: Make `StreamingErrorChunk` conform to `Error`
3. **Model Compatibility Documentation**: Clearly document which models support streaming
4. **Graceful Degradation**: Provide automatic fallback to non-streaming when streaming fails
5. **Enhanced Debugging**: Add more detailed error messages showing the actual chunk content that failed to parse

## **Workaround Currently Used**
```swift
// Fallback approach when streaming fails
if let streamingInteractor = interactor as? StreamingInteractor {
    do {
        // Try streaming first
        let stream = try await streamingInteractor.generateStream(...)
        // Process stream...
    } catch {
        // Fall back to non-streaming on any streaming error
        let result = try await interactor.generateNonStreaming(...)
    }
} else {
    // Use non-streaming by default
}
```

This issue significantly impacts the user experience as streaming provides better perceived performance, but the current parsing errors force fallback to slower non-streaming approaches for certain models.

## **Additional Context**

**Debug Log Extract:**
```
DEBUG: [APIClient] Streaming recipes with model: claude-3-5-haiku-20241022
DEBUG: [APIClient] Stream error received: StreamingErrorChunk(type: "error", error: AnthropicSDK.StreamingErrorChunk.ErrorDetail(type: "parsing_error", message: "Failed to parse streaming chunk: The data couldn't be read because it isn't in the correct format."))
```

**Application Context**: iOS SwiftUI app using Claude Vision API for ingredient identification and recipe generation. Vision streaming works perfectly, but text-only streaming consistently fails with haiku model.

**Impact**: Forces developers to implement complex fallback mechanisms and degrades user experience by falling back to slower non-streaming API calls.