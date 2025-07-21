# Contributing to Anthropic Swift SDK

We welcome contributions to the Anthropic Swift SDK! This document provides guidelines for contributing to the project.

## Development Principles

This project strictly follows **Test-Driven Development (TDD)** and **Behavior-Driven Development (BDD)** methodologies:

### TDD Cycle (MANDATORY)
**NEVER write production code without failing tests first**:

1. **RED Phase**: Write failing tests that define expected behavior
2. **GREEN Phase**: Write minimal implementation to make tests pass  
3. **REFACTOR Phase**: Improve code while keeping tests green
4. **Quality Gate**: All tests must pass before proceeding to next feature

### Quality Standards
- Test coverage ≥95% for all implemented features
- 100% test pass rate before moving forward
- Follow Apple's Swift API Design Guidelines
- Zero external dependencies (Foundation only: URLSession, Codable)
- Optimized for iOS/macOS performance constraints

## Getting Started

### Prerequisites
- Xcode 14.0+ 
- Swift 5.7+
- iOS 15+ / macOS 12+ deployment targets

### Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/tthew/anthropic-swift-sdk.git
   cd anthropic-swift-sdk
   ```

2. **Open in Xcode**
   ```bash
   open Package.swift
   ```

3. **Run tests to verify setup**
   ```bash
   swift test
   ```

4. **Run linting**
   ```bash
   swiftlint lint
   ```

## Development Workflow

### 1. Issue Assignment
- Check existing issues or create a new one
- Get assignment/approval before starting major changes
- Discuss architectural decisions in the issue thread

### 2. Branch Creation
```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### 3. TDD Implementation Process

#### Step 1: Write BDD Scenarios
```swift
// Example: Tests/AnthropicSDKTests/NewFeatureTests.swift
import XCTest
@testable import AnthropicSDK

final class NewFeatureTests: XCTestCase {
    func testFeatureBehaviorScenario1() throws {
        // Given - setup test conditions
        let client = try AnthropicClient(apiKey: "sk-ant-test")
        
        // When - execute the behavior
        let result = try await client.newFeature(input: "test")
        
        // Then - verify expectations
        XCTAssertEqual(result.output, "expected_value")
    }
}
```

#### Step 2: Run Tests (RED)
```bash
swift test --filter NewFeatureTests
# Tests should FAIL - this confirms you're testing new behavior
```

#### Step 3: Implement Minimal Code (GREEN)
```swift
// Sources/AnthropicSDK/NewFeature.swift
extension AnthropicClient {
    func newFeature(input: String) async throws -> FeatureResult {
        // Minimal implementation to make test pass
        return FeatureResult(output: "expected_value")
    }
}
```

#### Step 4: Run Tests Again
```bash
swift test --filter NewFeatureTests
# Tests should now PASS
```

#### Step 5: Refactor
- Clean up code
- Add proper error handling
- Optimize performance
- Ensure tests still pass

### 4. Testing Requirements

#### Run Full Test Suite
```bash
# All tests must pass
swift test

# Check coverage (must be ≥95%)
swift test --enable-code-coverage

# Generate coverage report
xcrun xccov view --report $(find . -name "*.xccovreport")
```

#### Test Categories
- **Unit Tests**: Core functionality, types, error handling
- **Integration Tests**: Live API interactions (with test keys)
- **Performance Tests**: Memory usage, concurrency, streaming
- **Edge Case Tests**: Network failures, malformed responses

### 5. Code Quality

#### SwiftLint
```bash
# Must pass with zero warnings
swiftlint lint

# Auto-fix issues when possible  
swiftlint --fix
```

#### Code Review Checklist
- [ ] All tests pass (≥95% coverage)
- [ ] SwiftLint passes with zero warnings
- [ ] Follows Swift API Design Guidelines
- [ ] Includes comprehensive documentation
- [ ] No external dependencies introduced
- [ ] Performance implications considered
- [ ] Error handling implemented
- [ ] Thread safety verified (actors used correctly)

## API Design Guidelines

### 1. Swift Native Patterns
```swift
// Good: Swift-native async/await
func sendMessage(_ text: String) async throws -> MessageResponse

// Bad: Callback-based patterns
func sendMessage(_ text: String, completion: @escaping (Result<MessageResponse, Error>) -> Void)
```

### 2. Progressive Disclosure
```swift
// Simple API for common use cases
let response = try await client.sendMessage("Hello")

// Advanced API for power users
let response = try await client.messages.create(
    model: .claude3_5Sonnet,
    messages: [.user("Hello")],
    maxTokens: 1000,
    temperature: 0.7
)
```

### 3. Type Safety
```swift
// Use enums for known values
public enum ClaudeModel: String, CaseIterable {
    case claude3_5Sonnet = "claude-3-5-sonnet-20241022"
}

// Validate parameters at compile time when possible
public init(maxTokens: Int) throws {
    guard maxTokens > 0 && maxTokens <= 4096 else {
        throw AnthropicError.invalidParameter("maxTokens must be 1-4096")
    }
}
```

## Documentation Standards

### 1. Code Documentation
```swift
/// Creates a new message using the Anthropic API
/// 
/// This method validates all request parameters before sending the request.
/// Rate limiting and retries are handled automatically.
/// 
/// - Parameters:
///   - request: The message creation request with all parameters
/// - Returns: The message response from the API containing the generated content  
/// - Throws: `AnthropicError` for validation errors, `HTTPError` for network issues
public func create(_ request: CreateMessageRequest) async throws -> MessageResponse
```

### 2. README Updates
- Update usage examples if API changes
- Add new features to feature list
- Update requirements if needed

### 3. CHANGELOG.md
```markdown
## [Unreleased]
### Added
- New feature description with example

### Changed  
- Breaking change description with migration guide

### Fixed
- Bug fix description
```

## Pull Request Process

### 1. Pre-submission Checklist
- [ ] All tests pass (`swift test`)
- [ ] Coverage ≥95% (`swift test --enable-code-coverage`)
- [ ] SwiftLint passes (`swiftlint lint`)
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Examples updated if API changed

### 2. PR Description Template
```markdown
## Description
Brief description of changes and motivation.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)  
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] New tests added for new functionality
- [ ] All existing tests pass
- [ ] Coverage maintained ≥95%

## TDD Process Followed
- [ ] Tests written first (RED phase)
- [ ] Minimal implementation (GREEN phase) 
- [ ] Code refactored while maintaining passing tests
- [ ] Quality gates maintained

## Checklist
- [ ] Self-review completed
- [ ] SwiftLint passes
- [ ] Documentation strings added/updated
- [ ] Breaking changes noted with migration guide
```

### 3. Review Process
- Maintainers will review within 48 hours
- Address feedback promptly
- Maintain test coverage during revisions
- Squash commits before merge

## Performance Guidelines

### 1. Memory Efficiency
```swift
// Use actors for thread-safe state
public actor HTTPClient {
    private let session: URLSession
}

// Avoid retain cycles in closures
stream.onReceive { [weak self] chunk in
    self?.process(chunk)
}
```

### 2. Network Optimization
- Reuse URLSession instances
- Implement connection pooling
- Add request/response caching
- Support request compression

### 3. Mobile Considerations
- Respect iOS memory constraints
- Handle background app states
- Optimize for cellular connections
- Provide configuration options

## Security Guidelines

### 1. API Key Handling
```swift
// Never log or expose API keys
private let apiKey: String // Make private

// Validate API key format
guard apiKey.hasPrefix("sk-ant-") else {
    throw AnthropicError.invalidAPIKey
}
```

### 2. Data Validation
```swift
// Always validate input parameters
guard !messages.isEmpty else {
    throw AnthropicError.invalidParameter("messages cannot be empty")
}
```

### 3. Network Security
- Use HTTPS only
- Validate SSL certificates
- Implement certificate pinning for production

## Release Process

### 1. Version Numbering
Follow [Semantic Versioning](https://semver.org/):
- `MAJOR.MINOR.PATCH`
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes (backward compatible)

### 2. Release Checklist
- [ ] All tests pass on CI
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in Package.swift
- [ ] Git tag created
- [ ] Release notes published

## CI/CD Integration

### Automated Testing Pipeline

All contributions are automatically validated through our comprehensive CI/CD pipeline:

#### **Pre-merge Validation**
1. **Multi-platform Testing**: Tests run on macOS 13/14 with Swift 5.7-5.10
2. **Linux Compatibility**: Compilation and core functionality verification  
3. **Test Coverage**: Must maintain ≥95% coverage across all test suites
4. **Performance Validation**: Automated performance regression detection
5. **Example Validation**: All example projects must build successfully

#### **Quality Gates**
- **Breaking Change Detection**: Automated API compatibility analysis
- **Documentation Validation**: Ensures docs match code changes
- **Security Scanning**: Basic security pattern analysis
- **Version Consistency**: Validates version numbers across files
- **Changelog Requirements**: Significant changes must update CHANGELOG.md

#### **Branch Protection Rules**
- All status checks must pass before merge
- Minimum 1 code review required
- Up-to-date branch requirement enforced
- Direct pushes to `main` branch blocked

#### **PR Workflow**
1. **Create PR**: Submit pull request targeting `main` branch
2. **Automatic Validation**: CI pipeline runs all quality checks
3. **PR Comments**: Automated feedback on validation results
4. **Review Process**: Maintainer review and approval
5. **Auto-merge**: Automatic merge when all checks pass and approved

### Troubleshooting CI Issues

#### **Common CI Failures**

**Test Failures:**
```bash
# Run tests locally to debug
swift test --parallel --enable-code-coverage

# Run specific test suite
swift test --filter StreamingTests
```

**Code Coverage Below 95%:**
```bash
# Generate coverage report
swift test --enable-code-coverage
xcrun llvm-cov show .build/debug/AnthropicSDKPackageTests.xctest/Contents/MacOS/AnthropicSDKPackageTests -instr-profile .build/debug/codecov/default.profdata
```

**Breaking Change Detection:**
- Review public API changes carefully
- Update CHANGELOG.md for breaking changes
- Consider deprecation before removal

**Documentation Issues:**
- Update README.md for new public APIs
- Add inline documentation for all public methods
- Ensure examples reflect current API

#### **Local Testing Before Push**
```bash
# Complete validation suite
swift test                           # All tests
swift build                          # Compilation check
swift build --target BasicChatExample   # Example builds
swift package resolve               # Dependency resolution
```

### Contributing to CI/CD

The CI/CD configuration lives in `.github/workflows/`:
- `ci.yml`: Main testing and validation pipeline
- `pr-validation.yml`: PR-specific quality checks

Improvements to the CI/CD pipeline are welcome through the standard PR process.

## Getting Help

### 1. Documentation
- [Apple's Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Official Anthropic API Documentation](https://docs.anthropic.com/claude/reference)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

### 2. Community
- [GitHub Discussions](https://github.com/tthew/anthropic-swift-sdk/discussions)
- [Issues](https://github.com/tthew/anthropic-swift-sdk/issues)
- [GitHub Actions](https://github.com/tthew/anthropic-swift-sdk/actions)

### 3. Maintainers
Tag maintainers in issues for:
- Architectural decisions
- Breaking change approval  
- Release coordination
- CI/CD pipeline changes

## License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.