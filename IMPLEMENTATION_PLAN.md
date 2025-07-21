# Swift SDK for Anthropic API - TDD/BDD Implementation Plan

## Overview

This document outlines the complete implementation plan for building a production-ready Swift SDK for the Anthropic API. The implementation strictly follows Test-Driven Development (TDD) and Behavior-Driven Development (BDD) principles to ensure high quality, robust code that meets real-world developer needs.

## TDD Approach

The implementation follows the strict TDD cycle:

```
API Design → Write Tests → RED → Minimal Implementation → GREEN → Refactor → Repeat
```

### TDD Principles
1. **Design API contracts upfront** based on user stories and requirements
2. **RED Phase**: Write failing tests that define expected behavior
3. **GREEN Phase**: Write minimal implementation to make tests pass
4. **REFACTOR**: Improve code while keeping tests green
5. **Quality Gates**: Each phase must pass all tests before proceeding

## Core Architecture

```
AnthropicSDK
├── Core Layer
│   ├── HTTPClient (Actor)
│   ├── Authentication
│   └── Error Handling
├── API Resources
│   ├── MessagesResource
│   ├── ModelsResource
│   ├── BatchesResource
│   └── FilesResource
├── Types & Models
│   ├── Message Types
│   ├── Model Definitions
│   └── Configuration
└── Advanced Features
    ├── Streaming
    ├── Tool Use
    └── Extended Thinking
```

## Design Principles

1. **Swift-First Design**: Native Swift patterns, not direct API translation
2. **Progressive Disclosure**: Simple methods for common tasks, advanced APIs for power users
3. **Type Safety**: Leverage Swift's type system for compile-time error prevention
4. **Performance**: Optimized for mobile constraints and efficient memory usage
5. **Zero Dependencies**: Built on Foundation's URLSession and Codable

## Implementation Phases

### Phase 1: Foundation & Core Messaging (TDD)

#### Target API Design
```swift
// Primary convenience API
let client = AnthropicClient(apiKey: "sk-ant-...")
let response = try await client.sendMessage("Hello, Claude")

// Advanced resource-based API
let message = try await client.messages.create(
    model: .claude4Sonnet,
    messages: [.user("Hello, Claude")],
    maxTokens: 1000
)
```

#### Week 1: Core Foundation (TDD)

**Day 1-2: Client Configuration**
1. **Design**: Define `ClientConfiguration` and `AnthropicClient` APIs
2. **BDD Scenarios**:
   ```gherkin
   GIVEN: A valid API key
   WHEN: I create an AnthropicClient
   THEN: The client should be properly configured
   
   GIVEN: An invalid API key
   WHEN: I create an AnthropicClient
   THEN: It should throw a configuration error
   ```
3. **RED**: Write `ClientInitializationTests`
4. **GREEN**: Implement minimal client with validation
5. **REFACTOR**: Add better error messages and validation

**Day 3-4: HTTP Foundation**
1. **Design**: Define HTTP networking interfaces
2. **BDD Scenarios**:
   ```gherkin
   GIVEN: A valid HTTP request
   WHEN: I send it via HTTPClient
   THEN: I should receive a proper response
   
   GIVEN: Network connectivity issues
   WHEN: I send a request
   THEN: It should retry with exponential backoff
   ```
3. **RED**: Write `HTTPClientTests` with retry scenarios
4. **GREEN**: Implement basic URLSession wrapper
5. **REFACTOR**: Extract authentication and retry logic

**Day 5: Error System**
1. **Design**: Define complete error hierarchy mapping HTTP status codes
2. **RED**: Write tests for all error conditions
3. **GREEN**: Implement error types and mapping
4. **REFACTOR**: Add user-friendly error messages

#### Week 2: Message API (TDD)

**Day 1-2: Core Message Types**
```swift
struct Message: Codable {
    let role: Role
    let content: [ContentBlock]
}

enum Role: String, Codable {
    case user, assistant
}

enum ContentBlock: Codable {
    case text(String)
    case image(ImageSource)
}
```

**TDD Process**:
1. **RED**: Write comprehensive serialization/deserialization tests
2. **GREEN**: Implement minimal Codable conformance
3. **REFACTOR**: Add validation and convenience initializers

**Day 3-4: Messages Resource**
```swift
actor MessagesResource {
    func create(
        model: Model,
        messages: [Message],
        maxTokens: Int,
        options: RequestOptions? = nil
    ) async throws -> Message
}
```

**BDD Scenarios**:
```gherkin
GIVEN: Valid message parameters
WHEN: I create a message
THEN: I should receive Claude's response

GIVEN: Invalid model specified
WHEN: I create a message
THEN: I should receive a model validation error
```

**Day 5: Integration Testing**
1. **RED**: Write end-to-end integration tests
2. **GREEN**: Fix integration issues
3. **REFACTOR**: Optimize request/response handling

### Phase 2: Configuration & Model Discovery (TDD)

#### Week 3: Configuration System

**Configuration API Design**:
```swift
let config = ClientConfiguration(
    apiKey: "sk-ant-...",
    baseURL: URL(string: "https://api.anthropic.com")!,
    timeout: 60.0,
    retryPolicy: .exponentialBackoff
)
let client = AnthropicClient(configuration: config)
```

**BDD Scenarios**:
```gherkin
GIVEN: Environment variable ANTHROPIC_API_KEY is set
WHEN: I create a client without explicit API key
THEN: It should use the environment variable

GIVEN: Custom timeout configuration
WHEN: I make a request that exceeds the timeout
THEN: It should fail with a timeout error
```

#### Week 4: Models API

**Models API Design**:
```swift
let models = try await client.models.list()
let claude4 = try await client.models.retrieve(.claude4Sonnet)
```

**TDD Implementation**:
1. **RED**: Write tests for model listing and retrieval
2. **GREEN**: Implement basic models API
3. **REFACTOR**: Add caching and model capability information

### Phase 3: Advanced Features (TDD)

#### Week 5-6: Streaming Implementation

**Streaming API Design**:
```swift
for try await delta in client.messages.stream(
    model: .claude4Sonnet,
    messages: [.user("Tell me a story")]
) {
    print(delta.content)
}
```

**BDD Scenarios**:
```gherkin
GIVEN: A streaming request
WHEN: I iterate over the response stream
THEN: I should receive incremental message deltas
AND: The stream should handle network interruptions gracefully

GIVEN: A stream that encounters an error
WHEN: I'm iterating over deltas
THEN: It should throw the appropriate error
```

**TDD Process**:
1. **Design**: Define streaming API with AsyncThrowingStream
2. **RED**: Write comprehensive streaming tests with mock SSE data
3. **GREEN**: Implement minimal AsyncSequence wrapper
4. **REFACTOR**: Add error handling and reconnection logic

#### Week 7-8: Tool Use System

**Tool Use API Design**:
```swift
struct CustomTool: Tool {
    let name = "calculator"
    let description = "Performs mathematical calculations"
    
    func execute(parameters: ToolParameters) async throws -> ToolResult {
        // Custom tool implementation
    }
}

let response = try await client.messages.create(
    model: .claude4Sonnet,
    messages: [.user("Calculate 15 * 23")],
    tools: [CustomTool()],
    toolChoice: .auto
)
```

**BDD Scenarios**:
```gherkin
GIVEN: A custom tool is registered
WHEN: Claude decides to use the tool
THEN: My tool should be executed with correct parameters
AND: The result should be incorporated into the response

GIVEN: A tool execution fails
WHEN: Claude attempts to use it
THEN: The error should be handled gracefully
```

### Phase 4: Production Features (TDD)

#### Week 9-10: Message Batches

**Batch API Design**:
```swift
let batch = try await client.batches.create(
    requests: batchRequests
)

let results = try await client.batches.results(batch.id)
```

#### Week 11: Files API

**Files API Design**:
```swift
let fileMetadata = try await client.files.upload(
    data: fileData,
    filename: "document.pdf"
)

let message = try await client.messages.create(
    model: .claude4Sonnet,
    messages: [.user("Analyze this document", files: [fileMetadata.id])]
)
```

## Test Structure

### Test Organization
```
Tests/
├── Unit/
│   ├── Client/
│   │   ├── AnthropicClientTests.swift
│   │   └── ConfigurationTests.swift
│   ├── Networking/
│   │   ├── HTTPClientTests.swift
│   │   └── AuthenticationTests.swift
│   ├── Types/
│   │   ├── MessageTests.swift
│   │   └── ErrorTests.swift
│   └── Resources/
│       ├── MessagesResourceTests.swift
│       └── ModelsResourceTests.swift
├── Integration/
│   ├── LiveAPITests.swift
│   └── EndToEndTests.swift
├── Performance/
│   ├── MemoryTests.swift
│   └── ConcurrencyTests.swift
└── Helpers/
    ├── MockServer.swift
    ├── TestData.swift
    └── TestHelpers.swift
```

### Mock Infrastructure
```swift
class MockAnthropicServer {
    func start() // Start local test server
    func stop()  // Cleanup
    
    func mockMessageResponse(_ response: Message)
    func mockError(_ error: AnthropicError)
    func mockStreamingResponse(_ deltas: [MessageDelta])
}

enum TestData {
    static let validMessage = Message(...)
    static let streamingDeltas = [MessageDelta(...)]
    static let errorResponse = AnthropicError(...)
}
```

## Quality Gates

### Before Moving to Next Phase:
1. **All tests must be GREEN** (100% pass rate)
2. **Code coverage ≥ 95%** for implemented features
3. **Performance tests pass** memory and speed benchmarks
4. **Integration tests pass** with live API
5. **Documentation updated** to match implemented API
6. **SwiftLint passes** with zero warnings

### TDD Implementation Pattern

Each feature follows this cycle:
1. **Design Session** (30 min): Define API contracts and user stories
2. **RED Phase** (1-2 hours): Write comprehensive failing tests
3. **GREEN Phase** (2-4 hours): Implement minimal code to pass tests
4. **REFACTOR Phase** (1-2 hours): Improve code while maintaining green tests
5. **Integration** (30 min): Ensure new code integrates properly
6. **Quality Gate** (30 min): Run full test suite and verify coverage

## Success Criteria

### Developer Experience
- Developer can integrate Claude in iOS/Mac app within 10 minutes
- SDK feels native to Swift developers (follows Apple design guidelines)
- Active community adoption and contributions

### Technical Performance
- Performance suitable for production apps (memory efficient, responsive)
- Full Anthropic API coverage including advanced features
- 95%+ test coverage with comprehensive CI/CD pipeline

### Quality Assurance
- Zero-defect releases through comprehensive testing
- Excellent documentation with working examples
- Responsive to community feedback and contributions

## Risk Mitigation

- **Weekly demos** to validate direction and gather feedback
- **Early beta releases** to Swift community for real-world validation
- **Performance benchmarking** against other SDKs
- **Conservative memory management** for mobile constraints
- **Comprehensive error handling** for network edge cases

## Long-term Vision

This SDK will become the standard way Swift developers integrate AI capabilities, supporting everything from simple chatbots to complex agentic applications, while maintaining the performance and developer experience expected on Apple platforms.

## Getting Started

See [LETS_GO.md](./LETS_GO.md) for the implementation kickoff prompt and first steps.