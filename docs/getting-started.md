---
layout: page
title: Getting Started
permalink: /getting-started/
---

# Getting Started

This guide will help you set up and start using the Anthropic Swift SDK in your iOS or macOS project.

## Prerequisites

Before you begin, ensure you have:

- **iOS 15.0+** / **macOS 12.0+** / **tvOS 15.0+** / **watchOS 8.0+**
- **Swift 5.9+**
- **Xcode 14.0+**
- An **Anthropic API key** (get one at [console.anthropic.com](https://console.anthropic.com))

## Installation

### Swift Package Manager (Recommended)

#### Option 1: Xcode Package Manager

1. Open your project in Xcode
2. Go to **File → Add Package Dependencies...**
3. Enter the repository URL:
   ```
   https://github.com/tthew/anthropic-swift-sdk
   ```
4. Select the version you want to use (latest is recommended)
5. Click **Add Package**

#### Option 2: Package.swift

Add the dependency to your `Package.swift` file:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YourProject",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/tthew/anthropic-swift-sdk", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "YourProject",
            dependencies: [
                .product(name: "AnthropicSDK", package: "anthropic-swift-sdk")
            ]
        )
    ]
)
```

## Initial Setup

### 1. Get Your API Key

1. Visit [console.anthropic.com](https://console.anthropic.com)
2. Sign in or create an account
3. Navigate to **API Keys**
4. Click **Create Key**
5. Copy your API key (it starts with `sk-ant-` followed by additional characters)

⚠️ **Keep your API key secure** - never commit it to version control or expose it in client-side code.

### 2. Configure Your API Key

#### Option A: Environment Variable (Recommended)

Set the environment variable in your development environment:

```bash
export ANTHROPIC_API_KEY=your-key-here
```

For Xcode projects, you can add this to your scheme:
1. Product → Scheme → Edit Scheme...
2. Go to **Run** → **Environment Variables**
3. Add `ANTHROPIC_API_KEY` with your API key value

#### Option B: Direct Initialization

```swift
import AnthropicSDK

let client = try AnthropicClient(apiKey: "your-token")
```

#### Option C: Secure Storage (Production Apps)

For production iOS/macOS apps, store the API key securely using Keychain:

```swift
import Security
import AnthropicSDK

// Store API key in Keychain
func storeAPIKey(_ apiKey: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "anthropic_api_key",
        kSecValueData as String: apiKey.data(using: .utf8)!
    ]
    SecItemAdd(query as CFDictionary, nil)
}

// Retrieve API key from Keychain
func getAPIKey() -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "anthropic_api_key",
        kSecReturnData as String: true
    ]
    
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    
    guard status == errSecSuccess,
          let data = item as? Data,
          let apiKey = String(data: data, encoding: .utf8) else {
        return nil
    }
    
    return apiKey
}

// Initialize client with secure storage
if let apiKey = getAPIKey() {
    let client = try AnthropicClient(apiKey: apiKey)
}
```

## Your First Message

### Basic Text Message

```swift
import AnthropicSDK

// Initialize the client
let client = try AnthropicClient() // Uses ANTHROPIC_API_KEY environment variable

// Send a simple message
let response = try await client.sendMessage("Hello, Claude! How are you today?")
print(response.content.first?.text ?? "No response")
```

### With Error Handling

```swift
import AnthropicSDK

func sendFirstMessage() async {
    do {
        let client = try AnthropicClient()
        let response = try await client.sendMessage("Hello, Claude!")
        
        if let text = response.content.first?.text {
            print("Claude says: \(text)")
        }
        
    } catch AnthropicError.invalidAPIKey {
        print("❌ Invalid API key. Please check your API key format.")
    } catch AnthropicError.missingEnvironmentKey {
        print("❌ Missing API key. Please set ANTHROPIC_API_KEY environment variable.")
    } catch HTTPError.rateLimited {
        print("❌ Rate limited. Please try again later.")
    } catch {
        print("❌ Unexpected error: \(error)")
    }
}

// Call in an async context
Task {
    await sendFirstMessage()
}
```

## Real-time Streaming

For longer responses, use streaming to get real-time updates:

```swift
import AnthropicSDK

func streamResponse() async {
    do {
        let client = try AnthropicClient()
        let stream = try await client.streamMessage(
            "Write a short story about a robot learning to paint"
        )
        
        print("Claude is writing", terminator: "")
        
        for try await chunk in stream {
            switch chunk {
            case .contentBlockDelta(let delta):
                if case .textDelta(let text) = delta.delta {
                    print(text, terminator: "")
                }
            case .messageDelta(let delta):
                if let usage = delta.usage {
                    print("\n[Tokens used: \(usage.outputTokens)]")
                }
            case .messageStop:
                print("\n✅ Response complete!")
            case .error(let error):
                print("\n❌ Stream error: \(error.localizedDescription)")
            default:
                break
            }
        }
        
    } catch {
        print("❌ Error: \(error)")
    }
}

Task {
    await streamResponse()
}
```

## Choosing the Right Model

Different models have different capabilities and performance characteristics:

```swift
import AnthropicSDK

func demonstrateModels() async {
    let client = try! AnthropicClient()
    
    // Claude 4 Sonnet - Best for coding and reasoning
    let codingResponse = try await client.sendMessage(
        "Write a Swift function to calculate fibonacci numbers",
        model: .claude4Sonnet,
        maxTokens: 500
    )
    
    // Claude 3.5 Haiku - Fastest for simple tasks
    let quickResponse = try await client.sendMessage(
        "What's the capital of France?",
        model: .claude3_5Haiku,
        maxTokens: 50
    )
    
    // Claude 4 Opus - Most capable for complex reasoning
    let complexResponse = try await client.sendMessage(
        "Explain the implications of quantum computing on cryptography",
        model: .claude4Opus,
        maxTokens: 1000
    )
}
```

### Model Recommendations

Use the built-in model recommendation system:

```swift
let client = try AnthropicClient()

// Get fastest model for simple tasks
let fastModel = await client.models.recommendModel(
    requiresVision: false,
    preferSpeed: true
)

// Get most capable model for complex reasoning
let smartModel = await client.models.recommendModel(
    requiresVision: false, 
    preferSpeed: false
)

// Get vision-capable model for image analysis
let visionModel = await client.models.recommendModel(
    requiresVision: true,
    preferSpeed: false
)

print("Fast model: \(fastModel)")
print("Smart model: \(smartModel)")
print("Vision model: \(visionModel)")
```

## Configuration for Different Environments

### iOS/Mobile Configuration

```swift
import AnthropicSDK

let mobileClient = try AnthropicClient(
    apiKey: "your-api-key",
    configuration: .mobile
)

// Mobile configuration includes:
// - Lower connection timeout (30s)
// - Reduced concurrent requests (3)
// - Aggressive caching enabled
// - Shorter retry delays
```

### Server/Backend Configuration

```swift
import AnthropicSDK

let serverClient = try AnthropicClient(
    apiKey: "your-api-key",
    configuration: .server
)

// Server configuration includes:
// - Higher connection timeout (60s)
// - More concurrent requests (10)
// - Caching disabled (for consistency)
// - More aggressive retry strategy
```

### Custom Configuration

```swift
import AnthropicSDK

let customConfig = ClientConfiguration(
    connectionTimeout: 45,         // Connection timeout in seconds
    resourceTimeout: 300,          // Total request timeout in seconds
    maxConcurrentRequests: 5,      // Max simultaneous requests
    enableCaching: true,           // Enable response caching
    enableRetry: true,             // Enable automatic retries
    maxRetryAttempts: 3,           // Number of retry attempts
    retryBaseDelay: 1.0            // Base delay between retries
)

let client = try AnthropicClient(
    apiKey: "your-api-key",
    configuration: customConfig
)
```

## SwiftUI Integration

Here's a simple SwiftUI view that uses the SDK:

```swift
import SwiftUI
import AnthropicSDK

struct ChatView: View {
    @State private var message = ""
    @State private var response = ""
    @State private var isLoading = false
    
    private let client = try! AnthropicClient()
    
    var body: some View {
        VStack(spacing: 20) {
            TextEditor(text: $response)
                .border(Color.gray)
                .frame(minHeight: 200)
            
            HStack {
                TextField("Enter your message...", text: $message)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    sendMessage()
                }
                .disabled(isLoading || message.isEmpty)
            }
        }
        .padding()
    }
    
    private func sendMessage() {
        isLoading = true
        response = ""
        
        Task {
            do {
                let result = try await client.sendMessage(message)
                await MainActor.run {
                    response = result.content.first?.text ?? "No response"
                    message = ""
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    response = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}
```

## SwiftUI Streaming Chat

For a more advanced streaming chat interface:

```swift
import SwiftUI
import AnthropicSDK

struct StreamingChatView: View {
    @State private var message = ""
    @State private var chatHistory: [ChatMessage] = []
    @State private var isStreaming = false
    @State private var currentResponse = ""
    
    private let client = try! AnthropicClient()
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(chatHistory) { chat in
                            ChatBubble(message: chat)
                                .id(chat.id)
                        }
                        
                        if isStreaming {
                            ChatBubble(message: ChatMessage(
                                id: UUID(),
                                text: currentResponse,
                                isUser: false
                            ))
                            .id("streaming")
                        }
                    }
                    .padding()
                }
                .onChange(of: chatHistory.count) { _ in
                    withAnimation {
                        proxy.scrollTo(chatHistory.last?.id, anchor: .bottom)
                    }
                }
                .onChange(of: currentResponse) { _ in
                    withAnimation {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }
            
            HStack {
                TextField("Type a message...", text: $message)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    sendStreamingMessage()
                }
                .disabled(isStreaming || message.isEmpty)
            }
            .padding()
        }
    }
    
    private func sendStreamingMessage() {
        let userMessage = ChatMessage(id: UUID(), text: message, isUser: true)
        chatHistory.append(userMessage)
        
        let messageToSend = message
        message = ""
        isStreaming = true
        currentResponse = ""
        
        Task {
            do {
                let stream = try await client.streamMessage(messageToSend)
                
                for try await chunk in stream {
                    switch chunk {
                    case .contentBlockDelta(let delta):
                        if case .textDelta(let text) = delta.delta {
                            await MainActor.run {
                                currentResponse += text
                            }
                        }
                    case .messageStop:
                        await MainActor.run {
                            let assistantMessage = ChatMessage(
                                id: UUID(),
                                text: currentResponse,
                                isUser: false
                            )
                            chatHistory.append(assistantMessage)
                            currentResponse = ""
                            isStreaming = false
                        }
                    case .error(let error):
                        await MainActor.run {
                            let errorMessage = ChatMessage(
                                id: UUID(),
                                text: "Error: \(error.localizedDescription)",
                                isUser: false
                            )
                            chatHistory.append(errorMessage)
                            currentResponse = ""
                            isStreaming = false
                        }
                    default:
                        break
                    }
                }
                
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(
                        id: UUID(),
                        text: "Error: \(error.localizedDescription)",
                        isUser: false
                    )
                    chatHistory.append(errorMessage)
                    isStreaming = false
                }
            }
        }
    }
}

struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isUser: Bool
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            Text(message.text)
                .padding(12)
                .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(12)
                .frame(maxWidth: .infinity * 0.8, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}
```

## Next Steps

Now that you have the basics working:

1. **Explore Advanced Features**:
   - [Tool Use](examples.html#tool-use) - Let Claude use custom tools
   - [Extended Thinking](examples.html#extended-thinking) - Access Claude's reasoning
   - [Batch Processing](examples.html#batch-operations) - Process multiple requests efficiently

2. **Check Out Examples**:
   - Browse the [Examples](examples.html) page for real-world usage patterns
   - Look at the example projects in the repository's `Examples/` directory

3. **Performance Optimization**:
   - Configure the client for your specific use case
   - Implement proper error handling and retry logic
   - Use streaming for long-form content

4. **Production Considerations**:
   - Implement secure API key storage
   - Add proper error handling and user feedback
   - Consider rate limiting and usage monitoring

## Common Issues

### "Missing API Key" Error

```swift
// ❌ This will fail
let client = try AnthropicClient()

// ✅ Set environment variable or use direct initialization
let client = try AnthropicClient(apiKey: "your-token")
```

### "Invalid API Key" Error

Make sure your API key starts with `sk-ant-`:

```swift
// ❌ Wrong format
let client = try AnthropicClient(apiKey: "your-token")

// ✅ Correct format
let client = try AnthropicClient(apiKey: "your-token")
```

### Network Timeout Issues

Configure appropriate timeouts for your use case:

```swift
let config = ClientConfiguration(
    connectionTimeout: 60,    // Increase for slower connections
    resourceTimeout: 300      // Increase for longer responses
)

let client = try AnthropicClient(
    apiKey: "your-key",
    configuration: config
)
```

## Support

If you encounter any issues:

1. Check the [Troubleshooting](troubleshooting.html) guide
2. Review the [API Reference](api-reference.html) for detailed documentation
3. Look at the [Examples](examples.html) for common usage patterns
4. Report issues on [GitHub](https://github.com/tthew/anthropic-swift-sdk/issues)

Happy coding with Claude! 🚀