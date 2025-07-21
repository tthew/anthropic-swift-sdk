# Anthropic Swift SDK

[![CI](https://github.com/tthew/anthropic-swift-sdk/workflows/CI/badge.svg)](https://github.com/tthew/anthropic-swift-sdk/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/tthew/anthropic-swift-sdk/branch/main/graph/badge.svg)](https://codecov.io/gh/tthew/anthropic-swift-sdk)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)](https://github.com/tthew/anthropic-swift-sdk)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

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
- Swift 5.9+
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
    model: .claude4Sonnet,
    maxTokens: 1000
)
```

### 3. Stream Real-time Responses

```swift
let stream = try await client.streamMessage("Write a story about space exploration")

for try await chunk in stream {
    switch chunk {
    case .messageStart(let start):
        print("Message started: \(start.message.id)")
    case .contentBlockStart:
        print("Content starting...")
    case .contentBlockDelta(let delta):
        if case .textDelta(let text) = delta.delta {
            print(text, terminator: "")
        }
    case .messageDelta(let delta):
        // Message metadata updates (usage, stop reason)
        if let usage = delta.usage {
            print("\n[Tokens: \(usage.outputTokens)]")
        }
        if let stopReason = delta.delta.stopReason {
            print("\n[Stopped: \(stopReason)]")
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
let modelInfo = try await client.models.retrieve(.claude4Sonnet)
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
| `claude4Opus` | Most intelligent model with hybrid reasoning | 200K tokens | ✅ |
| `claude4Sonnet` | Advanced model with superior coding capabilities | 200K tokens | ✅ |
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
// Handle streaming with proper error recovery and parsing resilience
func processStream(_ stream: MessageStream) async throws {
    do {
        for try await chunk in stream {
            switch chunk {
            case .contentBlockDelta(let delta):
                // Process text content
                if case .textDelta(let text) = delta {
                    print(text, terminator: "")
                }
            case .error(let streamError):
                // Handle streaming errors gracefully
                print("Stream error: \(streamError.localizedDescription)")
                if streamError.error.type == "parsing_error" {
                    // Log detailed error for debugging
                    print("Parsing error details: \(streamError.error.message)")
                    // Continue processing other chunks
                    continue
                } else {
                    // Handle other error types as needed
                    break
                }
            case .messageStop:
                print("\nStream complete!")
                break
            default:
                // Handle other chunk types
                break
            }
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

## Troubleshooting

### Streaming Parsing Errors

If you encounter streaming parsing errors with certain models (especially Claude 3.5 Haiku):

#### Enhanced Error Handling (v1.1.3+)
The SDK now includes comprehensive streaming chunk support and improved parser resilience:

```swift
for try await chunk in stream {
    switch chunk {
    case .messageDelta(let delta):
        // Handle message metadata updates (v1.1.3+)
        if let usage = delta.usage {
            print("Current tokens: \(usage.outputTokens)")
        }
        if let stopReason = delta.delta.stopReason {
            print("Stop reason: \(stopReason)")
        }
    case .error(let streamError):
        // StreamingErrorChunk now conforms to Error protocol
        print("Stream error: \(streamError.localizedDescription)")
        
        switch streamError.error.type {
        case "parsing_error":
            // Enhanced parsing error with detailed debugging info
            print("Raw data causing issue: \(streamError.error.message)")
            // You can choose to continue or fallback to non-streaming
            continue
        case "unknown_chunk_type":
            // New chunk types from API updates
            print("Unknown chunk type - may need SDK update")
            continue
        default:
            // Handle other streaming errors
            break
        }
    default:
        // Process normal chunks
        break
    }
}
```

#### Fallback Strategy
```swift
// Implement automatic fallback for parsing errors
do {
    let stream = try await client.streamMessage("Your prompt", model: .claude3_5Haiku)
    for try await chunk in stream {
        if case .error(let streamError) = chunk,
           streamError.error.type == "parsing_error" {
            // Fallback to non-streaming for this model
            throw StreamingFallbackError()
        }
        // Process successful chunks...
    }
} catch {
    // Use non-streaming as fallback
    let response = try await client.sendMessage("Your prompt", model: .claude3_5Haiku)
    print(response.content.first?.text ?? "")
}
```

### Claude 4 Models Not Available

If Claude 4 models (`.claude4Opus`, `.claude4Sonnet`) are not available after updating:

#### Check Your SDK Version
```swift
import AnthropicSDK

// Print version information
SDKVersion.printVersion()

// Quick check for Claude 4 support
print("Claude 4 Support: \(SDKVersion.hasClaude4Support)")
```

#### Clear Swift Package Manager Cache
```bash
# Option 1: Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Option 2: Clear SPM cache
swift package reset
swift package clean

# Option 3: Force package resolution (in your project)
swift package resolve --force-resolved-versions
```

#### Update Package Dependency
In Xcode:
1. File → Package Dependencies
2. Select "anthropic-swift-sdk" 
3. Right-click → Update Package

Or update to specific version in `Package.swift`:
```swift
.package(url: "https://github.com/tthew/anthropic-swift-sdk", from: "1.1.2")
```

#### Verify Latest Version
Expected output with Claude 4 support:
```
Anthropic Swift SDK v1.1.3
Commit: [latest]
Claude 4 Support: ✅ Available

Available Models:
  - claude-opus-4-20250514
  - claude-sonnet-4-20250514
  - claude-3-5-sonnet-20241022
  [... other models]
```

If you're still seeing older models only, ensure you're using **version 1.1.3 or later**.

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

1. Clone the repository
2. Open `Package.swift` in Xcode
3. Run tests to ensure everything is working
4. Make your changes following TDD methodology
5. Ensure all tests pass and coverage remains >95%

### CI/CD Pipeline

This project uses GitHub Actions for continuous integration and deployment:

#### **Automated Testing**
- **Multi-Platform Testing**: Runs on macOS 13/14 with Swift 5.9-5.10
- **Linux Compatibility**: Basic compilation and core functionality tests
- **Comprehensive Coverage**: All 124+ test cases with >95% code coverage
- **Performance Validation**: Automated performance regression detection
- **Example Validation**: Ensures all example projects build successfully

#### **Quality Gates**
- **Code Quality**: Automated validation of API consistency and documentation
- **Breaking Change Detection**: Analyzes public API changes for compatibility
- **Security Scanning**: Basic security pattern analysis for common issues
- **Documentation Validation**: Ensures documentation stays current with code changes

#### **Branch Protection**
- **Required Status Checks**: All CI tests must pass before merge
- **PR Review Process**: Minimum 1 review required for all changes
- **Automatic Validation**: PRs are automatically validated for:
  - Test coverage and passing status
  - Changelog updates for significant changes
  - Documentation completeness for new APIs
  - Security pattern compliance

#### **Contribution Workflow**
1. **Fork & Branch**: Create a feature branch from `main`
2. **Develop**: Make changes following TDD methodology
3. **Test Locally**: Run `swift test` to ensure all tests pass
4. **Submit PR**: Create pull request targeting `main` branch
5. **CI Validation**: Wait for automated checks to complete
6. **Code Review**: Address any feedback from maintainers
7. **Merge**: PR automatically merges when all checks pass and approved

The CI pipeline runs automatically on:
- Pull request creation/updates
- Pushes to `main` branch
- Manual workflow triggers

See [GitHub Actions](.github/workflows/) for complete workflow configurations.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 📚 [Official Anthropic API Documentation](https://docs.anthropic.com/claude/reference)
- 🐛 [Report SDK Issues](https://github.com/tthew/anthropic-swift-sdk/issues)
- 💬 [Community Discussions](https://github.com/tthew/anthropic-swift-sdk/discussions)

## Disclaimer

This is an unofficial library. For official support or questions about the Anthropic API itself, please contact Anthropic directly through their official channels. This SDK is provided "as is" without warranty of any kind.