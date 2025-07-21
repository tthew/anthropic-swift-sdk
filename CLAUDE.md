# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a Swift SDK for the Anthropic API, designed for iOS and macOS applications. The project follows strict Test-Driven Development (TDD) and Behavior-Driven Development (BDD) principles throughout implementation.

## Development Methodology

### TDD Cycle (MANDATORY)
This project strictly follows the TDD cycle - **NEVER write production code without failing tests first**:

1. Design API contract upfront
2. RED Phase: Write failing tests that define expected behavior
3. GREEN Phase: Write minimal implementation to make tests pass
4. REFACTOR Phase: Improve code while keeping tests green
5. Quality Gate: All tests must pass before proceeding to next feature

### Quality Standards
- Test coverage ≥95% for all implemented features
- 100% test pass rate before moving forward
- Follow Apple's Swift API Design Guidelines
- Zero external dependencies (Foundation only: URLSession, Codable)
- Optimized for iOS/macOS performance constraints

## Architecture

The SDK follows a layered architecture with progressive disclosure:

```
.
├── Core Layer
│   ├── HTTPClient (Actor) - Thread-safe networking
│   ├── Authentication - API key management
│   └── Error Handling - Comprehensive error mapping
├── API Resources
│   ├── MessagesResource - Text generation and streaming
│   ├── ModelsResource - Model discovery and capabilities
│   ├── BatchesResource - Bulk operations
│   └── FilesResource - File upload/management
├── Types & Models
│   ├── Message Types - Request/response models
│   ├── Model Definitions - Claude model enumerations
│   └── Configuration - Client configuration
└── Advanced Features
    ├── Streaming - AsyncSequence for real-time responses
    ├── Tool Use - Custom tool integration
    └── Extended Thinking - Reasoning step access
```

## API Design Approach

The SDK provides two API styles:
- **Convenience API**: `client.sendMessage("Hello, Claude")` for simple use cases
- **Resource API**: `client.messages.create(model: .claude4Sonnet, messages: [...])` for advanced features

## Development Commands

### Testing
```bash
# Run all tests (must be GREEN before committing)
swift test

# Run tests with coverage
swift test --enable-code-coverage

# Run specific test file
swift test --filter ClientInitializationTests

# Run single test method
swift test --filter ClientInitializationTests/testClientInitializationWithValidAPIKey
```

### Building
```bash
# Build the package
swift build

# Build for specific platform
swift build --arch arm64

# Build in release mode
swift build -c release
```

### Linting
```bash
# Run SwiftLint (must pass with zero warnings)
swiftlint lint

# Auto-fix SwiftLint issues
swiftlint --fix
```

## Test Structure

Tests are organized by layer and functionality:
```
Tests/
├── Unit/
│   ├── Client/ - Client initialization and configuration tests
│   ├── Networking/ - HTTP client and authentication tests
│   ├── Types/ - Message and error type tests
│   └── Resources/ - API resource tests
├── Integration/ - Live API and end-to-end tests
├── Performance/ - Memory usage and concurrency tests
└── Helpers/ - Mock server and test utilities
```

## Key Implementation Rules

1. **TDD First**: Each feature starts with BDD scenarios written as failing tests
2. **Minimal Implementation**: Only write code to make current failing test pass
3. **Quality Gates**: All tests GREEN + ≥95% coverage before proceeding
4. **Swift Native**: Use Swift patterns, not direct API translation
5. **Actor-Based Networking**: Use Swift actors for thread-safe HTTP operations
6. **AsyncSequence Streaming**: Leverage Swift's async/await for streaming responses

## Platform Requirements

- iOS 15+ / macOS 12+ (for modern async/await support)
- Swift 5.9+
- Foundation framework only (zero external dependencies)

## Error Handling Strategy

The SDK maps all HTTP status codes to specific `AnthropicError` subtypes:
- Authentication errors (401)
- Rate limiting (429) with retry logic
- Model validation errors
- Network connectivity issues
- Token limit exceeded

## Performance Considerations

- Memory efficient streaming for large responses
- Connection pooling for HTTP requests
- Intelligent retry strategies with circuit breakers
- Mobile-optimized memory pressure handling
- Request/response middleware for extensibility

## Implementation Phases

The project is implemented in 4 phases:
1. **Foundation**: Core networking, authentication, basic messaging
2. **Configuration**: Client configuration, model discovery, enhanced error handling
3. **Advanced Features**: Streaming, tool use, extended thinking
4. **Production Features**: Batch operations, file handling, optimization

Each phase must complete with all tests GREEN before proceeding to the next.