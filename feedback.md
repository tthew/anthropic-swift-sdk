# Bug Report: SDK v1.1.3 message_delta Parsing Error

## **Issue Summary**
The Anthropic Swift SDK v1.1.3 still has a parsing error when processing `message_delta` chunks during streaming operations. Despite claims that the message_delta fix was included in v1.1.3, the parsing error persists with specific chunk formats.

## **Current Error Details (SDK v1.1.3)**
```
StreamingErrorChunk(
  type: "error", 
  error: StreamingErrorChunk.ErrorDetail(
    type: "parsing_error", 
    message: "Failed to parse streaming chunk: Missing key 'input_tokens' at usage | Raw data preview: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\",\"stop_sequence\":null},\"usage\":{\"output_tokens\":1309}}"
  )
)
```

## **Environment**
- **SDK Version**: v1.1.3 
- **Platform**: iOS 18.5+ (Swift 5.0)
- **Issue**: message_delta chunks missing `input_tokens` field in usage object
- **API**: Affects streaming operations across multiple models

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

## **Root Cause Analysis (SDK v1.1.3)**
The issue appears to be in the SDK's message_delta chunk parser, specifically:

1. **Missing input_tokens Field**: The parser expects both `input_tokens` and `output_tokens` in the usage object, but message_delta chunks near stream completion may only contain `output_tokens`

2. **Rigid Parsing Structure**: The SDK parser doesn't handle partial usage information gracefully

3. **message_delta vs message_stop**: The error occurs during message_delta processing instead of proper message_stop handling

## **Raw Chunk Analysis**
The failing chunk structure is:
```json
{
  "type": "message_delta",
  "delta": {
    "stop_reason": "end_turn",
    "stop_sequence": null
  },
  "usage": {
    "output_tokens": 1309
    // Missing: "input_tokens": <number>
  }
}
```

## **Suggested Investigation Areas**

1. **Usage Object Validation**: Make the parser handle partial usage objects where `input_tokens` may be missing in final message_delta chunks

2. **Parser Flexibility**: Allow usage objects to contain only `output_tokens` for end-of-stream scenarios

3. **Chunk Type Handling**: Ensure message_delta chunks near stream completion are processed correctly before transitioning to message_stop

4. **Error Type Issues**: `StreamingErrorChunk` still doesn't conform to Swift's `Error` protocol in v1.1.3:
   ```swift
   // This fails to compile:
   continuation.finish(throwing: streamError) 
   
   // Requires workaround:
   continuation.finish(throwing: APIError.invalidResponse)
   ```

## **Recommended Fixes (SDK v1.1.3)**

1. **Fix Usage Object Parsing**: Make `input_tokens` optional in usage objects during message_delta parsing:
   ```swift
   // Current (fails):
   struct Usage {
       let inputTokens: Int  // Required but missing in final chunks
       let outputTokens: Int
   }
   
   // Suggested (works):
   struct Usage {
       let inputTokens: Int? // Optional for partial usage info
       let outputTokens: Int
   }
   ```

2. **Add Error Protocol Conformance**: Make `StreamingErrorChunk` conform to `Error` for proper error handling

3. **Improved Chunk Validation**: Handle message_delta chunks that only contain final statistics gracefully

4. **Better End-of-Stream Handling**: Ensure message_delta chunks with stop_reason properly transition to message_stop

5. **Enhanced Debug Information**: The current error message is excellent - it shows the raw chunk data which helps identify the exact parsing issue

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

**Debug Log Extract (SDK v1.1.3):**
```
DEBUG: [APIClient 8F3388B7] SDK v1.1.3 - Vision stream error: StreamingErrorChunk(type: "error", error: AnthropicSDK.StreamingErrorChunk.ErrorDetail(type: "parsing_error", message: "Failed to parse streaming chunk: Missing key 'input_tokens' at usage | Raw data preview: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\",\"stop_sequence\":null},\"usage\":{\"output_tokens\":1309}}"))
```

**Application Context**: iOS SwiftUI app using Claude Vision API for ingredient identification and recipe generation. The message_delta parsing issue affects both vision and text streaming operations in SDK v1.1.3.

**Impact**: Despite the v1.1.3 "message_delta fix", streaming still fails due to rigid parsing requirements for usage objects. This forces developers to maintain complex fallback mechanisms and degrades user experience.

## **Priority: HIGH**
This parsing error prevents the streaming functionality from working reliably, which is a core feature for improving user experience in real-time AI applications. The error message now provides exact chunk content, making the root cause clear - the parser expects `input_tokens` but final message_delta chunks may omit this field.