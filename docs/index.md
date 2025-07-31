---
layout: home
title: "Anthropic Swift SDK"
---

# Anthropic Swift SDK

[![CI](https://github.com/tthew/anthropic-swift-sdk/workflows/CI/badge.svg)](https://github.com/tthew/anthropic-swift-sdk/actions/workflows/ci.yml)
[![iOS Tests](https://img.shields.io/badge/iOS%20Tests-iOS%2015%2B%20Simulator-blue.svg)](https://github.com/tthew/anthropic-swift-sdk/actions/workflows/ci.yml)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)](https://github.com/tthew/anthropic-swift-sdk)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/tthew/anthropic-swift-sdk/blob/main/LICENSE)

> **⚠️ UNOFFICIAL LIBRARY**: This is an unofficial Swift SDK for the Anthropic Claude API and is not affiliated with, endorsed, or supported by Anthropic in any way.

A modern, native Swift SDK for the Anthropic Claude API, designed specifically for iOS and macOS applications. Built with modern Swift features including async/await, actors, and comprehensive error handling.

## ✨ Key Features

- 🚀 **Native Swift API** - Idiomatic Swift patterns with full async/await support
- 🔄 **Real-time Streaming** - AsyncSequence-based streaming for live responses
- 🛠 **Tool Integration** - Built-in support for Claude's advanced tool use capabilities
- 🧠 **Extended Thinking** - Access to Claude's reasoning process and step-by-step logic
- 📦 **Batch Operations** - Efficient bulk message processing for high-throughput scenarios
- 📁 **File Management** - Upload and manage files for document analysis and processing
- ⚡ **Performance Optimized** - Connection pooling, intelligent caching, and retry strategies
- 🎯 **Type Safe** - Comprehensive type definitions for all API interactions
- 📱 **Mobile Ready** - Optimized configurations for iOS/macOS memory and performance constraints
- 🧪 **Test Driven** - >95% test coverage with comprehensive BDD test suite

## 🚀 Quick Start

### Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tthew/anthropic-swift-sdk", from: "1.0.0")
]
```

### Basic Usage

```swift
import AnthropicSDK

// Initialize client
let client = try AnthropicClient(apiKey: "sk-ant-your-key")

// Send a message
let response = try await client.sendMessage("Hello, Claude!")
print(response.content.first?.text ?? "No response")

// Stream responses in real-time
let stream = try await client.streamMessage("Write a story about space exploration")
for try await chunk in stream {
    if case .contentBlockDelta(let delta) = chunk,
       case .textDelta(let text) = delta.delta {
        print(text, terminator: "")
    }
}
```

## 🎯 Advanced Features

### Tool Use Integration

Define custom tools and let Claude use them to solve complex problems:

```swift
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

let response = try await client.sendMessageWithTools(
    "What is 15 * 23 + 45?",
    tools: tools
) { toolName, input in
    // Handle tool execution
    switch toolName {
    case "calculate":
        return evaluateExpression(input["expression"] as? String ?? "")
    default:
        return "Unknown tool"
    }
}
```

### Extended Thinking Access

Access Claude's reasoning process for complex problem-solving:

```swift
let response = try await client.sendMessageWithThinking(
    "Solve this logic puzzle: Three friends each have different pets...",
    thinkingMode: .extended
)

// Access reasoning steps
if let thinkingSteps = response.thinking {
    print("Claude's reasoning:")
    for step in thinkingSteps {
        print("- \(step.content)")
    }
}
```

### Batch Processing

Process multiple requests efficiently:

```swift
let requests = [
    BatchRequest(customId: "task_1", method: .POST, url: "/v1/messages", 
                body: CreateMessageRequest(model: .claude3_5Sonnet, 
                                         messages: [.user("Summarize renewable energy")],
                                         maxTokens: 500)),
    BatchRequest(customId: "task_2", method: .POST, url: "/v1/messages",
                body: CreateMessageRequest(model: .claude3_5Sonnet,
                                         messages: [.user("Explain machine learning")], 
                                         maxTokens: 500))
]

let batch = try await client.batches.create(CreateBatchRequest(requests: requests))
```

## 📚 Documentation

- **[Getting Started Guide](getting-started.html)** - Complete setup and basic usage
- **[API Reference](api-reference.html)** - Detailed API documentation
- **[Examples](examples.html)** - Real-world usage examples
- **[Troubleshooting](troubleshooting.html)** - Common issues and solutions

## 🤖 Supported Models

| Model | Description | Context Window | Vision Support |
|-------|-------------|----------------|----------------|
| `claude4Opus` | Most intelligent model with hybrid reasoning | 200K tokens | ✅ |
| `claude4Sonnet` | Advanced model with superior coding capabilities | 200K tokens | ✅ |
| `claude3_5Sonnet` | Most intelligent, balanced performance | 200K tokens | ✅ |
| `claude3_5Haiku` | Fastest, lightweight for everyday tasks | 200K tokens | ❌ |
| `claude3Opus` | Most powerful for complex reasoning | 200K tokens | ✅ |
| `claude3Sonnet` | Balanced intelligence and speed | 200K tokens | ✅ |
| `claude3Haiku` | Fast and cost-effective | 200K tokens | ✅ |

## 📋 Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 5.9+
- Xcode 14.0+

## 🔧 Architecture

The SDK follows a layered architecture with progressive disclosure:

```
Core Layer
├── HTTPClient (Actor) - Thread-safe networking
├── Authentication - API key management  
└── Error Handling - Comprehensive error mapping

API Resources
├── MessagesResource - Text generation and streaming
├── ModelsResource - Model discovery and capabilities
├── BatchesResource - Bulk operations
└── FilesResource - File upload/management

Advanced Features
├── Streaming - AsyncSequence for real-time responses
├── Tool Use - Custom tool integration
└── Extended Thinking - Reasoning step access
```

## 🏗️ Development Methodology

This project follows strict **Test-Driven Development (TDD)** and **Behavior-Driven Development (BDD)** principles:

1. **RED Phase**: Write failing tests that define expected behavior
2. **GREEN Phase**: Write minimal implementation to pass tests
3. **REFACTOR Phase**: Improve code while keeping tests green
4. **Quality Gate**: All tests must pass with ≥95% coverage before proceeding

## 🤝 Contributing

We welcome contributions! The project uses comprehensive CI/CD with:

- **Multi-Platform Testing**: macOS, iOS Simulator, Linux compatibility
- **Quality Gates**: 95%+ test coverage requirement
- **Automated Validation**: All example projects and documentation
- **Security Scanning**: Basic security pattern analysis

See our [Contributing Guide](https://github.com/tthew/anthropic-swift-sdk/blob/main/CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/tthew/anthropic-swift-sdk/blob/main/LICENSE) file for details.

## 🔗 Links

- 📚 [Official Anthropic API Documentation](https://docs.anthropic.com/claude/reference)
- 🐛 [Report Issues](https://github.com/tthew/anthropic-swift-sdk/issues)
- 💬 [Discussions](https://github.com/tthew/anthropic-swift-sdk/discussions)
- 📦 [Swift Package Index](https://swiftpackageindex.com/tthew/anthropic-swift-sdk)

---

**Disclaimer**: This is an unofficial library. For official support or questions about the Anthropic API itself, please contact Anthropic directly through their official channels.