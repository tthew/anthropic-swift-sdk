# Anthropic Swift SDK

> **⚠️ UNOFFICIAL LIBRARY**: This is an unofficial Swift SDK for the Anthropic Claude API and is not affiliated with, endorsed, or supported by Anthropic in any way. This library is developed and maintained independently.

> **🤖 AI-ASSISTED DEVELOPMENT**: This SDK was designed and implemented using Claude Code, Anthropic's agentic coding tool, following strict Test-Driven Development (TDD) and Behavior-Driven Development (BDD) principles.

A native Swift SDK for the Anthropic Claude API, designed for iOS and macOS applications. Built with modern Swift features including async/await, actors, and comprehensive error handling.

## Features

- 🚀 **Native Swift API**: Idiomatic Swift patterns with async/await support
- 🔄 **Real-time Streaming**: AsyncSequence-based streaming for live responses
- 🛠 **Tool Integration**: Built-in support for Claude's tool use capabilities
- 🧠 **Extended Thinking**: Access to Claude's reasoning process
- 📦 **Batch Operations**: Efficient bulk message processing
- 📁 **File Management**: Upload and manage files for Claude processing
- ⚡ **Performance Optimized**: Connection pooling, caching, and retry strategies
- 🎯 **Type Safe**: Comprehensive type definitions for all API interactions
- 📱 **Mobile Ready**: Optimized configurations for iOS/macOS constraints
- 🧪 **Test Driven**: >95% test coverage with comprehensive BDD test suite

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.7+
- Xcode 14.0+

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tthew/anthropic-swift-sdk", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/tthew/anthropic-swift-sdk`
3. Select the version you want to use

## Quick Start

### 1. Initialize the Client

```swift
import AnthropicSDK

// Using API key directly
let client = try AnthropicClient(apiKey: "sk-ant-your-api-key")

// Using environment variable (ANTHROPIC_API_KEY)
let client = try AnthropicClient()
```

### 2. Send a Simple Message

```swift
// Simple text message
let response = try await client.sendMessage("Hello, Claude!")
print(response.content.first?.text ?? "No response")

// With specific model and parameters
let response = try await client.sendMessage(
    "Explain quantum computing",
    model: .claude3_5Sonnet,
    maxTokens: 1000
)
```

### 3. Stream Real-time Responses

```swift
let stream = try await client.streamMessage("Write a story about space exploration")

for try await chunk in stream {
    switch chunk {
    case .contentBlockStart:
        print("Starting response...")
    case .contentBlockDelta(let delta):
        if case .textDelta(let text) = delta {
            print(text, terminator: "")
        }
    case .messageStop:
        print("\nResponse complete!")
    default:
        break
    }
}
```

## Advanced Usage

### Tool Use

Define tools and let Claude use them to solve complex problems:

```swift
import AnthropicSDK

// Define available tools
let tools = [
    Tool(
        name: "calculate",
        description: "Perform mathematical calculations",
        inputSchema: [
            "type": "object",
            "properties": [
                "expression": [
                    "type": "string",
                    "description": "Mathematical expression to evaluate"
                ]
            ],
            "required": ["expression"]
        ]
    )
]

// Handle tool execution
let response = try await client.sendMessageWithTools(
    "What is 15 * 23 + 45?",
    tools: tools
) { toolName, input in
    switch toolName {
    case "calculate":
        if let expression = input["expression"] as? String {
            // Your calculation logic here
            return "The result is: \(evaluateExpression(expression))"
        }
        return "Invalid expression"
    default:
        return "Unknown tool: \(toolName)"
    }
}
```

### Model Discovery

Discover available models and their capabilities:

```swift
// List all available models
let modelList = try await client.models.list()
for model in modelList.data {
    print("Model: \(model.id)")
    print("Context Window: \(model.contextWindow)")
    print("Supports Vision: \(model.supportsVision)")
    print("Description: \(model.description)")
    print("---")
}

// Get information about a specific model
let modelInfo = try await client.models.retrieve(.claude3_5Sonnet)
print("Model: \(modelInfo.id)")
print("Context Window: \(modelInfo.contextWindow) tokens")

// Get all Claude models (offline)
let allModels = await client.models.getAllClaudeModels()

// Get model recommendations
let fastModel = await client.models.recommendModel(
    requiresVision: false,
    preferSpeed: true
)
print("Recommended fast model: \(fastModel)")

let visionModel = await client.models.recommendModel(
    requiresVision: true,
    preferSpeed: false
)
print("Recommended vision model: \(visionModel)")
```

### Extended Thinking

Access Claude's reasoning process:

```swift
let response = try await client.sendMessageWithThinking(
    "Solve this logic puzzle: Three friends each have a different pet...",
    thinkingMode: .extended
)

// Access the reasoning steps
if let thinkingSteps = response.thinking {
    print("Claude's reasoning:")
    for step in thinkingSteps {
        print("- \(step.content)")
    }
}

print("Final answer: \(response.content)")
```

### Batch Operations

Process multiple requests efficiently:

```swift
// Create batch requests
let requests = [
    BatchRequest(
        customId: "task_1",
        method: .POST,
        url: "/v1/messages",
        body: CreateMessageRequest(
            model: .claude3_5Sonnet,
            messages: [.user("Summarize the importance of renewable energy")],
            maxTokens: 500
        )
    ),
    BatchRequest(
        customId: "task_2", 
        method: .POST,
        url: "/v1/messages",
        body: CreateMessageRequest(
            model: .claude3_5Sonnet,
            messages: [.user("Explain machine learning basics")],
            maxTokens: 500
        )
    )
]

// Submit batch
let batch = try await client.batches.create(
    CreateBatchRequest(requests: requests)
)

// Monitor progress
let updatedBatch = try await client.batches.retrieve(batch.id)
print("Status: \(updatedBatch.processingStatus)")
print("Progress: \(updatedBatch.requestCounts.succeeded)/\(updatedBatch.requestCounts.total)")

// Retrieve results when complete
if updatedBatch.isCompleted {
    let results = try await client.batches.results(batch.id)
    for result in results.data {
        print("Request \(result.customId): \(result.isSuccess ? "✓" : "✗")")
    }
}
```

### File Operations

Upload and manage files for Claude processing:

```swift
// Upload a document
let fileData = try Data(contentsOf: documentURL)
let uploadRequest = FileUploadRequest(
    file: fileData,
    filename: "analysis.pdf",
    contentType: "application/pdf",
    purpose: .document
)

let uploadResponse = try await client.files.upload(uploadRequest)
let file = uploadResponse.file

// Use file in a message
let response = try await client.messages.create(
    model: .claude3_5Sonnet,
    messages: [.user("Analyze this document and provide key insights")],
    maxTokens: 1000,
    files: [FileReference(fileId: file.id)]
)

// List all files
let filesList = try await client.files.list(purpose: .document)
print("Total files: \(filesList.data.count)")

// Download file content
let content = try await client.files.downloadContent(file.id)
```

### Performance Optimization

Configure the client for different environments:

```swift
// Mobile-optimized configuration
let mobileClient = try AnthropicClient(
    apiKey: "sk-ant-your-key",
    configuration: .mobile
)

// Server environment configuration
let serverClient = try AnthropicClient(
    apiKey: "sk-ant-your-key", 
    configuration: .server
)

// Custom configuration
let customConfig = ClientConfiguration(
    connectionTimeout: 45,
    maxConcurrentRequests: 8,
    enableCaching: true,
    enableRetry: true,
    maxRetryAttempts: 3
)
let customClient = try AnthropicClient(
    apiKey: "sk-ant-your-key",
    configuration: customConfig
)
```

## Model Support

| Model | Description | Context Window | Vision Support |
|-------|-------------|----------------|----------------|
| `claude3_5Sonnet` | Most intelligent, balanced performance | 200K tokens | ✅ |
| `claude3_5Haiku` | Fastest, lightweight for everyday tasks | 200K tokens | ❌ |
| `claude3Opus` | Most powerful for complex reasoning | 200K tokens | ✅ |
| `claude3Sonnet` | Balanced intelligence and speed | 200K tokens | ✅ |
| `claude3Haiku` | Fast and cost-effective | 200K tokens | ✅ |

## Error Handling

The SDK provides comprehensive error handling:

```swift
do {
    let response = try await client.sendMessage("Hello, Claude!")
} catch AnthropicError.invalidAPIKey {
    print("Please check your API key")
} catch AnthropicError.invalidParameter(let message) {
    print("Invalid parameter: \(message)")
} catch HTTPError.rateLimited {
    print("Rate limited - please retry after delay")
} catch HTTPError.serverError(let statusCode) {
    print("Server error: \(statusCode)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Configuration Options

### Client Configuration

```swift
let config = ClientConfiguration(
    connectionTimeout: 60,        // Connection timeout (seconds)
    resourceTimeout: 300,         // Request timeout (seconds)  
    maxConcurrentRequests: 10,    // Max simultaneous requests
    enableCaching: false,         // Response caching
    enableRetry: true,           // Automatic retries
    maxRetryAttempts: 3,         // Retry attempts
    retryBaseDelay: 1.0          // Base retry delay (seconds)
)
```

### Retry Strategy

```swift
let retryStrategy = RetryStrategy(
    maxAttempts: 5,
    baseDelay: 1.0,
    maxDelay: 30.0,
    retryableStatusCodes: [408, 429, 500, 502, 503, 504]
)
```

### Circuit Breaker

```swift
let circuitBreaker = CircuitBreaker(
    failureThreshold: 5,      // Failures before opening
    recoveryTimeout: 60,      // Seconds before retry
    monitoringWindow: 300     // Window for failure counting
)
```

## Best Practices

### 1. Resource Management
```swift
// Use connection pooling for multiple requests
let client = try AnthropicClient(apiKey: "sk-ant-your-key")

// Prefer batch operations for bulk processing
let batchRequests = messages.map { message in 
    BatchRequest(customId: message.id, method: .POST, url: "/v1/messages", 
                body: CreateMessageRequest(model: .claude3_5Sonnet, messages: [message]))
}
```

### 2. Error Recovery
```swift
// Implement proper retry logic
func sendWithRetry(_ message: String, maxAttempts: Int = 3) async throws -> MessageResponse {
    for attempt in 1...maxAttempts {
        do {
            return try await client.sendMessage(message)
        } catch HTTPError.rateLimited {
            if attempt < maxAttempts {
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                continue
            }
            throw HTTPError.rateLimited
        }
    }
    fatalError("Should not reach here")
}
```

### 3. Streaming Best Practices
```swift
// Handle streaming with proper error recovery
func processStream(_ stream: MessageStream) async throws {
    do {
        for try await chunk in stream {
            // Process chunk
            await processChunk(chunk)
        }
    } catch {
        // Handle stream interruption
        print("Stream error: \(error)")
        // Implement fallback or retry logic
    }
}
```

## Testing

The SDK includes comprehensive test coverage:

```bash
# Run all tests
swift test

# Run with coverage
swift test --enable-code-coverage

# Run specific test suite
swift test --filter ClientInitializationTests
```

## Examples

Check out the `Examples/` directory for complete sample applications:

- **ChatApp**: Simple chat interface with streaming
- **ToolUseDemo**: Advanced tool integration example
- **BatchProcessor**: Bulk processing demonstration
- **FileAnalyzer**: Document upload and analysis

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

1. Clone the repository
2. Open `Package.swift` in Xcode
3. Run tests to ensure everything is working
4. Make your changes following TDD methodology
5. Ensure all tests pass and coverage remains >95%

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 📚 [Official Anthropic API Documentation](https://docs.anthropic.com/claude/reference)
- 🐛 [Report SDK Issues](https://github.com/tthew/anthropic-swift-sdk/issues)
- 💬 [Community Discussions](https://github.com/tthew/anthropic-swift-sdk/discussions)

## Disclaimer

This is an unofficial library. For official support or questions about the Anthropic API itself, please contact Anthropic directly through their official channels. This SDK is provided "as is" without warranty of any kind.