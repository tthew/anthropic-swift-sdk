---
layout: page
title: API Reference
permalink: /api-reference/
---

# API Reference

Complete reference for the Anthropic Swift SDK.

## Table of Contents

- [Client Initialization](#client-initialization)
- [Core Types](#core-types)
- [Messages API](#messages-api)
- [Models API](#models-api)
- [Batches API](#batches-api)
- [Files API](#files-api)
- [Streaming](#streaming)
- [Tool Use](#tool-use)
- [Extended Thinking](#extended-thinking)
- [Error Handling](#error-handling)
- [Configuration](#configuration)

## Client Initialization

### AnthropicClient

The main entry point for all SDK operations.

```swift
public struct AnthropicClient
```

#### Initializers

##### init(apiKey:baseURL:configuration:)

```swift
public init(
    apiKey: String, 
    baseURL: URL = URL(string: "https://api.anthropic.com")!, 
    configuration: ClientConfiguration = .default
) throws
```

Creates a client with an explicit API key.

**Parameters:**
- `apiKey`: Valid Anthropic API key starting with "sk-ant-"
- `baseURL`: Base URL for API requests (optional)
- `configuration`: Client configuration (optional)

**Throws:** `AnthropicError` if API key is invalid

##### init(baseURL:configuration:)

```swift
public init(
    baseURL: URL = URL(string: "https://api.anthropic.com")!, 
    configuration: ClientConfiguration = .default
) throws
```

Creates a client using the `ANTHROPIC_API_KEY` environment variable.

**Throws:** `AnthropicError` if environment variable is missing or invalid

#### Properties

```swift
public let apiKey: String
public let baseURL: URL
public let configuration: ClientConfiguration
public let messages: MessagesResource
public let models: ModelsResource
public let batches: BatchesResource
public let files: FilesResource
```

## Core Types

### ClaudeModel

```swift
public enum ClaudeModel: String, CaseIterable, Codable
```

Supported Claude models:

```swift
case claude4Opus = "claude-opus-4-20250514"
case claude4Sonnet = "claude-sonnet-4-20250514"
case claude3_5Sonnet = "claude-3-5-sonnet-20241022"
case claude3_5Haiku = "claude-3-5-haiku-20241022"
case claude3Opus = "claude-3-opus-20240229" 
case claude3Sonnet = "claude-3-sonnet-20240229"
case claude3Haiku = "claude-3-haiku-20240307"
```

### MessageContent

```swift
public enum MessageContent: Codable
```

**Cases:**
- `text(String)` - Plain text content
- `image(ImageContent)` - Image content with base64 data

### Message

```swift
public struct Message: Codable
```

**Properties:**
```swift
public let role: MessageRole
public let content: [MessageContent]
```

### MessageRole

```swift
public enum MessageRole: String, Codable
```

**Cases:**
- `user` - Messages from the user
- `assistant` - Messages from Claude

## Messages API

### MessagesResource

Handles message creation and streaming.

```swift
public struct MessagesResource
```

#### Methods

##### create

```swift
public func create(
    model: ClaudeModel,
    messages: [Message],
    maxTokens: Int,
    temperature: Double? = nil,
    topP: Double? = nil,
    topK: Int? = nil,
    stopSequences: [String]? = nil,
    system: String? = nil,
    tools: [Tool]? = nil,
    toolChoice: ToolChoice? = nil,
    stream: Bool = false,
    metadata: RequestMetadata? = nil
) async throws -> MessageResponse
```

Creates a message with comprehensive configuration options.

##### stream

```swift
public func stream(
    model: ClaudeModel,
    messages: [Message], 
    maxTokens: Int,
    temperature: Double? = nil,
    topP: Double? = nil,
    topK: Int? = nil,
    stopSequences: [String]? = nil,
    system: String? = nil,
    tools: [Tool]? = nil,
    toolChoice: ToolChoice? = nil,
    metadata: RequestMetadata? = nil
) -> AsyncThrowingStream<StreamingChunk, Error>
```

Creates a streaming message response.

#### Convenience Methods on AnthropicClient

##### sendMessage

```swift
public func sendMessage(
    _ text: String,
    model: ClaudeModel = .claude4Sonnet,
    maxTokens: Int = 1000
) async throws -> MessageResponse
```

Simple text message sending.

##### streamMessage

```swift
public func streamMessage(
    _ text: String,
    model: ClaudeModel = .claude4Sonnet,
    maxTokens: Int = 1000
) -> AsyncThrowingStream<StreamingChunk, Error>
```

Simple text message streaming.

##### sendMessageWithTools

```swift
public func sendMessageWithTools(
    _ text: String,
    tools: [Tool],
    model: ClaudeModel = .claude4Sonnet,
    maxTokens: Int = 1000,
    toolHandler: @escaping ToolHandler
) async throws -> MessageResponse
```

Message sending with tool use capabilities.

##### sendMessageWithThinking

```swift
public func sendMessageWithThinking(
    _ text: String,
    thinkingMode: ThinkingMode = .extended,
    model: ClaudeModel = .claude4Sonnet,
    maxTokens: Int = 1000
) async throws -> ThinkingResponse
```

Message sending with access to Claude's reasoning process.

## Models API

### ModelsResource

Handles model discovery and information retrieval.

```swift
public struct ModelsResource
```

#### Methods

##### list

```swift
public func list() async throws -> ModelListResponse
```

Lists all available models from the API.

##### retrieve

```swift
public func retrieve(_ model: ClaudeModel) async throws -> ModelInfo
```

Gets detailed information about a specific model.

##### getAllClaudeModels

```swift
public func getAllClaudeModels() async -> [ModelInfo]
```

Returns information about all Claude models (offline).

##### recommendModel

```swift
public func recommendModel(
    requiresVision: Bool = false,
    preferSpeed: Bool = false
) async -> ClaudeModel
```

Gets model recommendations based on requirements.

### ModelInfo

```swift
public struct ModelInfo: Codable
```

**Properties:**
```swift
public let id: String
public let type: String
public let displayName: String
public let contextWindow: Int
public let maxOutputTokens: Int
public let supportsVision: Bool
public let description: String
```

## Batches API

### BatchesResource

Handles batch operations for processing multiple requests efficiently.

```swift
public struct BatchesResource
```

#### Methods

##### create

```swift
public func create(_ request: CreateBatchRequest) async throws -> BatchResponse
```

Creates a new batch operation.

##### retrieve

```swift
public func retrieve(_ batchId: String) async throws -> BatchResponse
```

Retrieves batch status and information.

##### list

```swift
public func list(
    limit: Int? = nil,
    afterId: String? = nil,
    beforeId: String? = nil
) async throws -> BatchListResponse
```

Lists existing batches.

##### results

```swift
public func results(_ batchId: String) async throws -> BatchResultsResponse
```

Retrieves results from a completed batch.

### BatchRequest

```swift
public struct BatchRequest: Codable
```

**Properties:**
```swift
public let customId: String
public let method: HTTPMethod
public let url: String
public let body: CreateMessageRequest
```

### BatchResponse

```swift
public struct BatchResponse: Codable
```

**Properties:**
```swift
public let id: String
public let type: String
public let processingStatus: BatchStatus
public let requestCounts: BatchRequestCounts
public let endedAt: Date?
public let createdAt: Date
public let expiresAt: Date
```

## Files API

### FilesResource

Handles file upload and management for document processing.

```swift
public struct FilesResource
```

#### Methods

##### upload

```swift
public func upload(_ request: FileUploadRequest) async throws -> FileUploadResponse
```

Uploads a file to the Anthropic API.

##### list

```swift
public func list(
    purpose: FilePurpose? = nil,
    limit: Int? = nil,
    afterId: String? = nil,
    beforeId: String? = nil
) async throws -> FileListResponse
```

Lists uploaded files.

##### retrieve

```swift
public func retrieve(_ fileId: String) async throws -> FileInfo
```

Gets information about a specific file.

##### delete

```swift
public func delete(_ fileId: String) async throws -> FileDeletionResponse
```

Deletes a file.

##### downloadContent

```swift
public func downloadContent(_ fileId: String) async throws -> Data
```

Downloads file content.

### FileUploadRequest

```swift
public struct FileUploadRequest
```

**Properties:**
```swift
public let file: Data
public let filename: String
public let contentType: String
public let purpose: FilePurpose
```

### FileInfo

```swift
public struct FileInfo: Codable
```

**Properties:**
```swift
public let id: String
public let type: String
public let filename: String
public let sizeBytes: Int
public let purpose: FilePurpose
public let createdAt: Date
```

## Streaming

### StreamingChunk

```swift
public enum StreamingChunk: Codable
```

Represents different types of streaming chunks:

**Cases:**
- `messageStart(MessageStartChunk)` - Message initialization
- `contentBlockStart(ContentBlockStartChunk)` - Content block beginning
- `contentBlockDelta(ContentBlockDeltaChunk)` - Incremental content
- `contentBlockStop(ContentBlockStopChunk)` - Content block end
- `messageDelta(MessageDeltaChunk)` - Message metadata updates
- `messageStop` - Message completion
- `error(StreamingErrorChunk)` - Streaming errors

### Usage Example

```swift
let stream = try await client.streamMessage("Tell me a story")

for try await chunk in stream {
    switch chunk {
    case .contentBlockDelta(let delta):
        if case .textDelta(let text) = delta.delta {
            print(text, terminator: "")
        }
    case .messageDelta(let delta):
        if let usage = delta.usage {
            print("Tokens: \(usage.outputTokens)")
        }
    case .messageStop:
        print("\nComplete!")
    case .error(let error):
        print("Stream error: \(error.localizedDescription)")
    default:
        break
    }
}
```

## Tool Use

### Tool

```swift
public struct Tool: Codable
```

**Properties:**
```swift
public let name: String
public let description: String
public let inputSchema: [String: Any]
```

### ToolChoice

```swift
public enum ToolChoice: Codable
```

**Cases:**
- `auto` - Let Claude decide whether to use tools
- `any` - Force Claude to use at least one tool
- `tool(String)` - Force use of a specific tool

### ToolHandler

```swift
public typealias ToolHandler = (String, [String: Any]) async throws -> String
```

Function type for handling tool execution.

### Usage Example

```swift
let tools = [
    Tool(
        name: "calculator",
        description: "Perform mathematical calculations",
        inputSchema: [
            "type": "object",
            "properties": [
                "expression": [
                    "type": "string",
                    "description": "Math expression to evaluate"
                ]
            ],
            "required": ["expression"]
        ]
    )
]

let response = try await client.sendMessageWithTools(
    "What's 15 * 23?",
    tools: tools
) { toolName, input in
    switch toolName {
    case "calculator":
        return calculateExpression(input["expression"] as? String ?? "")
    default:
        return "Unknown tool"
    }
}
```

## Extended Thinking

### ThinkingMode

```swift
public enum ThinkingMode: String, Codable
```

**Cases:**
- `extended` - Access Claude's detailed reasoning process

### ThinkingResponse

```swift
public struct ThinkingResponse: Codable
```

**Properties:**
```swift
public let content: String
public let thinking: [ThinkingStep]?
public let usage: Usage
public let stopReason: StopReason?
```

### ThinkingStep

```swift
public struct ThinkingStep: Codable
```

**Properties:**
```swift
public let content: String
public let type: String
```

### Usage Example

```swift
let response = try await client.sendMessageWithThinking(
    "Solve this complex logic puzzle...",
    thinkingMode: .extended
)

if let thinking = response.thinking {
    print("Claude's reasoning:")
    for step in thinking {
        print("- \(step.content)")
    }
}

print("Final answer: \(response.content)")
```

## Error Handling

### AnthropicError

```swift
public enum AnthropicError: Error, LocalizedError
```

**Cases:**
- `invalidAPIKey` - Invalid API key format
- `emptyAPIKey` - Empty API key provided
- `missingEnvironmentKey` - No ANTHROPIC_API_KEY environment variable
- `invalidParameter(String)` - Invalid parameter value

### HTTPError

```swift
public enum HTTPError: Error, LocalizedError
```

**Cases:**
- `badRequest(String)` - 400 Bad Request
- `unauthorized` - 401 Unauthorized
- `forbidden` - 403 Forbidden
- `notFound` - 404 Not Found
- `rateLimited` - 429 Too Many Requests
- `serverError(Int)` - 5xx Server Errors
- `unknownError(Int, String?)` - Unknown HTTP errors

### Usage Example

```swift
do {
    let response = try await client.sendMessage("Hello!")
} catch AnthropicError.invalidAPIKey {
    print("Please check your API key")
} catch HTTPError.rateLimited {
    print("Rate limited - please retry later")
} catch HTTPError.serverError(let code) {
    print("Server error: \(code)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Configuration

### ClientConfiguration

```swift
public struct ClientConfiguration
```

**Properties:**
```swift
public let connectionTimeout: TimeInterval
public let resourceTimeout: TimeInterval
public let maxConcurrentRequests: Int
public let enableCaching: Bool
public let enableRetry: Bool
public let maxRetryAttempts: Int
public let retryBaseDelay: TimeInterval
```

### Predefined Configurations

```swift
public static let `default`: ClientConfiguration
public static let mobile: ClientConfiguration
public static let server: ClientConfiguration
```

### Usage Example

```swift
// Mobile-optimized configuration
let mobileConfig = ClientConfiguration.mobile

// Custom configuration
let customConfig = ClientConfiguration(
    connectionTimeout: 45,
    resourceTimeout: 300,
    maxConcurrentRequests: 8,
    enableCaching: true,
    enableRetry: true,
    maxRetryAttempts: 3,
    retryBaseDelay: 1.0
)

let client = try AnthropicClient(
    apiKey: "your-api-key",
    configuration: customConfig
)
```

---

For more examples and advanced usage patterns, see the [Examples](examples.html) section.