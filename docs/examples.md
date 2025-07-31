---
layout: page
title: Examples
permalink: /examples/
---

# Examples

This page provides comprehensive examples showing how to use the Anthropic Swift SDK in real-world scenarios.

## Table of Contents

- [Basic Chat](#basic-chat)
- [Streaming Responses](#streaming-responses)
- [Tool Use](#tool-use)
- [Extended Thinking](#extended-thinking)
- [Batch Operations](#batch-operations)
- [File Operations](#file-operations)
- [Model Discovery](#model-discovery)
- [SwiftUI Integration](#swiftui-integration)
- [iOS App Example](#ios-app-example)
- [macOS Command Line Tool](#macos-command-line-tool)

## Basic Chat

### Simple Message Exchange

```swift
import AnthropicSDK

func basicChatExample() async {
    do {
        // Initialize client with environment variable
        let client = try AnthropicClient()
        
        // Send a simple message
        let response = try await client.sendMessage(
            "Write a haiku about Swift programming",
            model: .claude3_5Sonnet,
            maxTokens: 100
        )
        
        if let textContent = response.content.first,
           case .text(let text) = textContent {
            print("Claude's response:")
            print(text)
            print("Tokens used: \(response.usage.outputTokens)")
        }
        
    } catch AnthropicError.missingEnvironmentKey {
        print("Please set ANTHROPIC_API_KEY environment variable")
    } catch {
        print("Error: \(error)")
    }
}
```

### Multi-turn Conversation

```swift
import AnthropicSDK

func conversationExample() async {
    do {
        let client = try AnthropicClient()
        
        // Build conversation history
        var messages: [Message] = [
            .user("I'm learning Swift. Can you help me understand optionals?"),
        ]
        
        // First response
        let response1 = try await client.messages.create(
            model: .claude4Sonnet,
            messages: messages,
            maxTokens: 500
        )
        
        // Add Claude's response to conversation
        messages.append(.assistant(response1.content))
        
        // Follow-up question
        messages.append(.user("Can you show me a practical example with error handling?"))
        
        let response2 = try await client.messages.create(
            model: .claude4Sonnet,
            messages: messages,
            maxTokens: 800
        )
        
        // Print the final response
        if let text = response2.content.first?.text {
            print("Claude's detailed explanation:")
            print(text)
        }
        
    } catch {
        print("Error: \(error)")
    }
}
```

## Streaming Responses

### Real-time Text Generation

```swift
import AnthropicSDK

func streamingExample() async {
    do {
        let client = try AnthropicClient()
        
        print("Streaming response from Claude:")
        print("-" * 40)
        
        let stream = try await client.streamMessage(
            "Write a short story about a robot learning to paint",
            model: .claude3_5Sonnet,
            maxTokens: 1000
        )
        
        var fullResponse = ""
        
        for try await chunk in stream {
            switch chunk {
            case .messageStart(let start):
                print("Message ID: \(start.message.id)")
                
            case .contentBlockStart:
                print("[Content starting...]")
                
            case .contentBlockDelta(let delta):
                if case .textDelta(let text) = delta.delta {
                    print(text, terminator: "")
                    fullResponse += text
                }
                
            case .messageDelta(let delta):
                if let usage = delta.usage {
                    print("\n[Tokens: \(usage.outputTokens)]")
                }
                if let stopReason = delta.delta.stopReason {
                    print("[Stop reason: \(stopReason)]")
                }
                
            case .messageStop:
                print("\n[Response complete!]")
                
            case .error(let error):
                print("\nStream error: \(error.localizedDescription)")
                if error.error.type == "parsing_error" {
                    // Continue processing - this is a recoverable error
                    print("(Continuing despite parsing error...)")
                    continue
                } else {
                    break
                }
                
            default:
                break
            }
        }
        
        print("\nFull response length: \(fullResponse.count) characters")
        
    } catch {
        print("Error: \(error)")
    }
}
```

### Streaming with Progress Updates

```swift
import AnthropicSDK

func streamingWithProgressExample() async {
    do {
        let client = try AnthropicClient()
        
        let stream = try await client.streamMessage(
            "Explain the theory of relativity in simple terms",
            model: .claude4Sonnet,
            maxTokens: 1500
        )
        
        var tokenCount = 0
        var startTime = Date()
        
        for try await chunk in stream {
            switch chunk {
            case .messageStart:
                startTime = Date()
                print("Starting response generation...")
                
            case .contentBlockDelta(let delta):
                if case .textDelta(let text) = delta.delta {
                    print(text, terminator: "")
                    tokenCount += text.split(separator: " ").count
                    
                    // Show progress every 50 tokens
                    if tokenCount % 50 == 0 {
                        let elapsed = Date().timeIntervalSince(startTime)
                        let rate = Double(tokenCount) / elapsed
                        print("\n[Progress: \(tokenCount) tokens, \(String(format: "%.1f", rate)) tokens/sec]")
                    }
                }
                
            case .messageDelta(let delta):
                if let usage = delta.usage {
                    let elapsed = Date().timeIntervalSince(startTime)
                    let rate = Double(usage.outputTokens) / elapsed
                    print("\n[Final: \(usage.outputTokens) tokens in \(String(format: "%.1f", elapsed))s, \(String(format: "%.1f", rate)) tokens/sec]")
                }
                
            case .messageStop:
                print("\nResponse generation complete!")
                
            default:
                break
            }
        }
        
    } catch {
        print("Error: \(error)")
    }
}
```

## Tool Use

### Calculator Tool

```swift
import AnthropicSDK
import Foundation

func calculatorToolExample() async {
    do {
        let client = try AnthropicClient()
        
        // Define calculator tool
        let calculatorTool = Tool(
            name: "calculator",
            description: "Performs basic mathematical calculations",
            inputSchema: [
                "type": "object",
                "properties": [
                    "expression": [
                        "type": "string",
                        "description": "Mathematical expression to evaluate (e.g., '2 + 3 * 4')"
                    ]
                ],
                "required": ["expression"]
            ]
        )
        
        let response = try await client.sendMessageWithTools(
            "What's 15 * 23 + 45 * 67? Also calculate the square root of 144.",
            tools: [calculatorTool],
            model: .claude4Sonnet
        ) { toolName, input in
            return await handleCalculatorTool(toolName: toolName, input: input)
        }
        
        if let text = response.content.first?.text {
            print("Claude's response with calculations:")
            print(text)
        }
        
    } catch {
        print("Error: \(error)")
    }
}

func handleCalculatorTool(toolName: String, input: [String: Any]) async -> String {
    guard toolName == "calculator",
          let expression = input["expression"] as? String else {
        return "Error: Invalid tool or input"
    }
    
    // Simple expression evaluator (in a real app, use a proper math parser)
    let result = evaluateExpression(expression)
    return "The result of \(expression) is \(result)"
}

func evaluateExpression(_ expression: String) -> Double {
    // Simplified evaluator - in production, use NSExpression or a proper parser
    let cleanExpression = expression.replacingOccurrences(of: " ", with: "")
    
    if let result = Double(cleanExpression) {
        return result
    }
    
    // Handle simple operations (this is very basic - use NSExpression for production)
    if cleanExpression.contains("+") {
        let parts = cleanExpression.components(separatedBy: "+")
        return parts.compactMap(Double.init).reduce(0, +)
    }
    
    if cleanExpression.contains("*") {
        let parts = cleanExpression.components(separatedBy: "*")
        return parts.compactMap(Double.init).reduce(1, *)
    }
    
    // For demonstration - use NSExpression in real apps
    return 0
}
```

### Weather Tool with API Integration

```swift
import AnthropicSDK
import Foundation

func weatherToolExample() async {
    do {
        let client = try AnthropicClient()
        
        let weatherTool = Tool(
            name: "get_weather",
            description: "Gets current weather information for a specified location",
            inputSchema: [
                "type": "object",
                "properties": [
                    "location": [
                        "type": "string",
                        "description": "City name or location to get weather for"
                    ],
                    "units": [
                        "type": "string",
                        "description": "Temperature units (celsius or fahrenheit)",
                        "enum": ["celsius", "fahrenheit"]
                    ]
                ],
                "required": ["location"]
            ]
        )
        
        let response = try await client.sendMessageWithTools(
            "What's the weather like in San Francisco and London? Please use Celsius for London and Fahrenheit for San Francisco.",
            tools: [weatherTool],
            model: .claude4Sonnet
        ) { toolName, input in
            return await handleWeatherTool(toolName: toolName, input: input)
        }
        
        if let text = response.content.first?.text {
            print("Weather report from Claude:")
            print(text)
        }
        
    } catch {
        print("Error: \(error)")
    }
}

func handleWeatherTool(toolName: String, input: [String: Any]) async -> String {
    guard toolName == "get_weather",
          let location = input["location"] as? String else {
        return "Error: Invalid weather tool request"
    }
    
    let units = input["units"] as? String ?? "celsius"
    
    // In a real app, you'd call a weather API like OpenWeatherMap
    // For this example, we'll return mock data
    let mockWeatherData = getMockWeatherData(for: location, units: units)
    return mockWeatherData
}

func getMockWeatherData(for location: String, units: String) -> String {
    let tempSuffix = units == "fahrenheit" ? "°F" : "°C"
    let temp = units == "fahrenheit" ? 72 : 22
    
    return """
    Current weather for \(location):
    Temperature: \(temp)\(tempSuffix)
    Conditions: Partly cloudy
    Humidity: 65%
    Wind: 8 mph SW
    """
}
```

### Multiple Tools Example

```swift
import AnthropicSDK

func multipleToolsExample() async {
    do {
        let client = try AnthropicClient()
        
        let tools = [
            Tool(
                name: "search_web",
                description: "Searches the web for information",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Search query"]
                    ],
                    "required": ["query"]
                ]
            ),
            Tool(
                name: "save_note",
                description: "Saves a note to the user's notebook",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "title": ["type": "string", "description": "Note title"],
                        "content": ["type": "string", "description": "Note content"]
                    ],
                    "required": ["title", "content"]
                ]
            ),
            Tool(
                name: "get_time",
                description: "Gets the current time in a specified timezone",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "timezone": ["type": "string", "description": "Timezone (e.g., 'America/New_York')"]
                    ],
                    "required": ["timezone"]
                ]
            )
        ]
        
        let response = try await client.sendMessageWithTools(
            "What time is it in Tokyo right now? Also search for information about the best ramen restaurants there and save your findings as a note.",
            tools: tools,
            model: .claude4Sonnet
        ) { toolName, input in
            return await handleMultipleTools(toolName: toolName, input: input)
        }
        
        if let text = response.content.first?.text {
            print("Claude's response using multiple tools:")
            print(text)
        }
        
    } catch {
        print("Error: \(error)")
    }
}

func handleMultipleTools(toolName: String, input: [String: Any]) async -> String {
    switch toolName {
    case "search_web":
        guard let query = input["query"] as? String else {
            return "Error: Missing search query"
        }
        return "Search results for '\(query)': [Mock search results about \(query)]"
        
    case "save_note":
        guard let title = input["title"] as? String,
              let content = input["content"] as? String else {
            return "Error: Missing title or content for note"
        }
        return "Note '\(title)' saved successfully with \(content.count) characters"
        
    case "get_time":
        guard let timezone = input["timezone"] as? String else {
            return "Error: Missing timezone"
        }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timezone)
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        let timeString = formatter.string(from: Date())
        return "Current time in \(timezone): \(timeString)"
        
    default:
        return "Error: Unknown tool '\(toolName)'"
    }
}
```

## Extended Thinking

### Problem Solving with Reasoning Steps

```swift
import AnthropicSDK

func extendedThinkingExample() async {
    do {
        let client = try AnthropicClient()
        
        let response = try await client.sendMessageWithThinking(
            """
            I have a 3-gallon jug and a 5-gallon jug. I need to measure exactly 4 gallons of water. 
            How can I do this? Please show your reasoning step by step.
            """,
            thinkingMode: .extended,
            model: .claude4Sonnet,
            maxTokens: 2000
        )
        
        // Show Claude's reasoning process
        if let thinkingSteps = response.thinking {
            print("🧠 Claude's Reasoning Process:")
            print("=" * 50)
            
            for (index, step) in thinkingSteps.enumerated() {
                print("\nStep \(index + 1):")
                print(step.content)
                print("-" * 30)
            }
        }
        
        print("\n💡 Final Answer:")
        print("=" * 50)
        print(response.content)
        
        print("\nToken usage:")
        print("- Input tokens: \(response.usage.inputTokens ?? 0)")
        print("- Output tokens: \(response.usage.outputTokens)")
        
    } catch {
        print("Error: \(error)")
    }
}
```

### Code Review with Thinking

```swift
import AnthropicSDK

func codeReviewWithThinkingExample() async {
    do {
        let client = try AnthropicClient()
        
        let codeToReview = """
        func quickSort<T: Comparable>(_ array: [T]) -> [T] {
            guard array.count > 1 else { return array }
            
            let pivot = array[array.count / 2]
            let less = array.filter { $0 < pivot }
            let equal = array.filter { $0 == pivot }
            let greater = array.filter { $0 > pivot }
            
            return quickSort(less) + equal + quickSort(greater)
        }
        """
        
        let response = try await client.sendMessageWithThinking(
            """
            Please review this Swift quicksort implementation. 
            Consider performance, correctness, and Swift best practices.
            
            \(codeToReview)
            """,
            thinkingMode: .extended,
            model: .claude4Sonnet,
            maxTokens: 1500
        )
        
        if let thinking = response.thinking {
            print("🔍 Code Review Analysis:")
            print("=" * 50)
            
            for (index, step) in thinking.enumerated() {
                print("\nAnalysis Step \(index + 1):")
                print(step.content)
            }
        }
        
        print("\n📝 Review Summary:")
        print("=" * 50)
        print(response.content)
        
    } catch {
        print("Error: \(error)")
    }
}
```

## Batch Operations

### Processing Multiple Documents

```swift
import AnthropicSDK

func batchProcessingExample() async {
    do {
        let client = try AnthropicClient()
        
        // Create batch requests for multiple document summaries
        let documents = [
            "Quarterly financial report showing 15% revenue growth...",
            "Market analysis indicating strong demand for our product...",
            "Customer feedback survey with 1000+ responses...",
            "Technical architecture proposal for new microservices..."
        ]
        
        let batchRequests = documents.enumerated().map { index, document in
            BatchRequest(
                customId: "document_\(index + 1)",
                method: .POST,
                url: "/v1/messages",
                body: CreateMessageRequest(
                    model: .claude3_5Sonnet,
                    messages: [.user("Summarize this document in 2-3 sentences: \(document)")],
                    maxTokens: 150
                )
            )
        }
        
        // Submit batch
        let batch = try await client.batches.create(
            CreateBatchRequest(requests: batchRequests)
        )
        
        print("Batch created: \(batch.id)")
        print("Status: \(batch.processingStatus)")
        
        // Monitor progress
        var attempts = 0
        let maxAttempts = 30 // 5 minutes with 10-second intervals
        
        while attempts < maxAttempts {
            let updatedBatch = try await client.batches.retrieve(batch.id)
            
            print("Progress: \(updatedBatch.requestCounts.succeeded)/\(updatedBatch.requestCounts.total) completed")
            
            if updatedBatch.isCompleted {
                // Retrieve results
                let results = try await client.batches.results(batch.id)
                
                print("\n📊 Batch Results:")
                print("=" * 50)
                
                for result in results.data {
                    print("\nDocument \(result.customId):")
                    if result.isSuccess {
                        if let responseBody = result.response?.body,
                           let content = responseBody.content.first?.text {
                            print("Summary: \(content)")
                        }
                    } else {
                        print("❌ Failed: \(result.error?.message ?? "Unknown error")")
                    }
                }
                break
            }
            
            // Wait before checking again
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            attempts += 1
        }
        
        if attempts >= maxAttempts {
            print("Timeout waiting for batch completion")
        }
        
    } catch {
        print("Error: \(error)")
    }
}
```

### Batch Analysis with Error Handling

```swift
import AnthropicSDK

func batchAnalysisExample() async {
    do {
        let client = try AnthropicClient()
        
        // Create analysis requests
        let analysisTopics = [
            "Analyze the environmental impact of electric vehicles",
            "Compare iOS and Android development frameworks",
            "Evaluate the future of remote work post-pandemic",
            "Assess blockchain technology's role in finance"
        ]
        
        let requests = analysisTopics.enumerated().map { index, topic in
            BatchRequest(
                customId: "analysis_\(index + 1)",
                method: .POST,
                url: "/v1/messages",
                body: CreateMessageRequest(
                    model: .claude4Sonnet,
                    messages: [.user(topic)],
                    maxTokens: 800
                )
            )
        }
        
        let batch = try await client.batches.create(
            CreateBatchRequest(requests: requests)
        )
        
        // Wait for completion with exponential backoff
        var waitTime: UInt64 = 5_000_000_000 // Start with 5 seconds
        let maxWaitTime: UInt64 = 60_000_000_000 // Max 60 seconds
        
        while true {
            let status = try await client.batches.retrieve(batch.id)
            
            switch status.processingStatus {
            case .completed:
                let results = try await client.batches.results(batch.id)
                await displayBatchResults(results)
                return
                
            case .failed:
                print("❌ Batch processing failed")
                return
                
            case .processing, .validating:
                print("⏳ Processing... (\(status.requestCounts.succeeded)/\(status.requestCounts.total))")
                try await Task.sleep(nanoseconds: waitTime)
                waitTime = min(waitTime * 2, maxWaitTime) // Exponential backoff
                
            default:
                print("Status: \(status.processingStatus)")
                try await Task.sleep(nanoseconds: waitTime)
            }
        }
        
    } catch {
        print("Error: \(error)")
    }
}

func displayBatchResults(_ results: BatchResultsResponse) async {
    print("\n📈 Analysis Results:")
    print("=" * 60)
    
    for result in results.data {
        print("\n🔍 \(result.customId.capitalized):")
        print("-" * 40)
        
        if result.isSuccess {
            if let content = result.response?.body?.content.first?.text {
                // Display first 200 characters with ellipsis
                let preview = content.count > 200 ? String(content.prefix(200)) + "..." : content
                print(preview)
            }
        } else {
            print("❌ Error: \(result.error?.message ?? "Unknown error")")
        }
    }
}
```

## File Operations

### Document Analysis

```swift
import AnthropicSDK
import Foundation

func fileAnalysisExample() async {
    do {
        let client = try AnthropicClient()
        
        // Example: Upload a PDF document
        guard let documentURL = Bundle.main.url(forResource: "sample_report", withExtension: "pdf"),
              let documentData = try? Data(contentsOf: documentURL) else {
            print("Sample document not found")
            return
        }
        
        let uploadRequest = FileUploadRequest(
            file: documentData,
            filename: "sample_report.pdf",
            contentType: "application/pdf",
            purpose: .document
        )
        
        print("📄 Uploading document...")
        let uploadResponse = try await client.files.upload(uploadRequest)
        let file = uploadResponse.file
        
        print("✅ Document uploaded: \(file.filename) (\(file.sizeBytes) bytes)")
        
        // Analyze the document
        let response = try await client.messages.create(
            model: .claude4Sonnet,
            messages: [.user("Please analyze this document and provide key insights, main findings, and recommendations.")],
            maxTokens: 1500,
            files: [FileReference(fileId: file.id)]
        )
        
        if let text = response.content.first?.text {
            print("\n🔍 Document Analysis:")
            print("=" * 50)
            print(text)
        }
        
        // List all uploaded files
        let filesList = try await client.files.list(purpose: .document)
        print("\n📁 Uploaded files (\(filesList.data.count) total):")
        for file in filesList.data.prefix(5) {
            print("- \(file.filename) (\(file.sizeBytes) bytes)")
        }
        
        // Clean up - delete the uploaded file
        let deletionResponse = try await client.files.delete(file.id)
        if deletionResponse.deleted {
            print("\n🗑️ File deleted successfully")
        }
        
    } catch {
        print("Error: \(error)")
    }
}
```

### Batch File Processing

```swift
import AnthropicSDK
import Foundation

func batchFileProcessingExample() async {
    do {
        let client = try AnthropicClient()
        
        // Upload multiple files
        let filenames = ["report1.txt", "report2.txt", "report3.txt"]
        var uploadedFiles: [FileInfo] = []
        
        for filename in filenames {
            // Mock file data - in real app, load from disk
            let content = "Sample content for \(filename)..."
            let data = content.data(using: .utf8)!
            
            let uploadRequest = FileUploadRequest(
                file: data,
                filename: filename,
                contentType: "text/plain",
                purpose: .document
            )
            
            let uploadResponse = try await client.files.upload(uploadRequest)
            uploadedFiles.append(uploadResponse.file)
            print("✅ Uploaded: \(filename)")
        }
        
        // Create batch analysis requests
        let batchRequests = uploadedFiles.enumerated().map { index, file in
            BatchRequest(
                customId: "file_analysis_\(index + 1)",
                method: .POST,
                url: "/v1/messages",
                body: CreateMessageRequest(
                    model: .claude3_5Sonnet,
                    messages: [.user("Summarize the key points in this document and identify any action items.")],
                    maxTokens: 300,
                    files: [FileReference(fileId: file.id)]
                )
            )
        }
        
        // Process batch
        let batch = try await client.batches.create(
            CreateBatchRequest(requests: batchRequests)
        )
        
        print("\n⏳ Processing \(uploadedFiles.count) files...")
        
        // Wait for completion
        while true {
            let status = try await client.batches.retrieve(batch.id)
            
            if status.isCompleted {
                let results = try await client.batches.results(batch.id)
                
                print("\n📊 File Analysis Results:")
                print("=" * 50)
                
                for (index, result) in results.data.enumerated() {
                    print("\n📄 \(uploadedFiles[index].filename):")
                    if result.isSuccess,
                       let content = result.response?.body?.content.first?.text {
                        print(content)
                    } else {
                        print("❌ Analysis failed")
                    }
                }
                break
            }
            
            print("Progress: \(status.requestCounts.succeeded)/\(status.requestCounts.total)")
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        }
        
        // Clean up uploaded files
        for file in uploadedFiles {
            try await client.files.delete(file.id)
        }
        print("\n🗑️ Cleaned up uploaded files")
        
    } catch {
        print("Error: \(error)")
    }
}
```

## Model Discovery

### Model Capabilities Explorer

```swift
import AnthropicSDK

func modelDiscoveryExample() async {
    do {
        let client = try AnthropicClient()
        
        print("🤖 Discovering Available Models")
        print("=" * 50)
        
        // List all available models from API
        let modelList = try await client.models.list()
        
        print("Available models from API:")
        for model in modelList.data.prefix(5) {
            print("- \(model.id)")
            print("  Context: \(model.contextWindow) tokens")
            print("  Vision: \(model.supportsVision ? "✅" : "❌")")
            print("  Description: \(model.description)")
            print()
        }
        
        // Get all Claude models (offline)
        let allClaudeModels = await client.models.getAllClaudeModels()
        
        print("\nAll Claude Models (offline):")
        for model in allClaudeModels {
            print("- \(model.displayName) (\(model.id))")
            print("  Context: \(model.contextWindow) tokens")
            print("  Max output: \(model.maxOutputTokens) tokens")
            print("  Vision: \(model.supportsVision ? "✅" : "❌")")
            print()
        }
        
        // Get model recommendations
        print("Model Recommendations:")
        print("-" * 30)
        
        let fastModel = await client.models.recommendModel(
            requiresVision: false,
            preferSpeed: true
        )
        print("Fastest model: \(fastModel)")
        
        let smartModel = await client.models.recommendModel(
            requiresVision: false,
            preferSpeed: false
        )
        print("Most capable model: \(smartModel)")
        
        let visionModel = await client.models.recommendModel(
            requiresVision: true,
            preferSpeed: false
        )
        print("Best vision model: \(visionModel)")
        
        // Test model capabilities
        await testModelCapabilities(client, model: smartModel)
        
    } catch {
        print("Error: \(error)")
    }
}

func testModelCapabilities(_ client: AnthropicClient, model: ClaudeModel) async {
    print("\n🧪 Testing Model Capabilities: \(model)")
    print("-" * 40)
    
    let testPrompts = [
        ("Reasoning", "If all roses are flowers and some flowers fade quickly, what can we conclude about roses?"),
        ("Creativity", "Write a haiku about programming"),
        ("Analysis", "What are the pros and cons of remote work?"),
        ("Code", "Write a Swift function to reverse a string")
    ]
    
    for (category, prompt) in testPrompts {
        do {
            let response = try await client.sendMessage(
                prompt,
                model: model,
                maxTokens: 200
            )
            
            if let text = response.content.first?.text {
                print("\n\(category) Test:")
                print("Q: \(prompt)")
                print("A: \(text.prefix(100))...")
                print("Tokens: \(response.usage.outputTokens)")
            }
        } catch {
            print("\n\(category) Test: ❌ Failed (\(error))")
        }
    }
}
```

## SwiftUI Integration

### Complete Chat App

```swift
import SwiftUI
import AnthropicSDK

struct ChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var chatModel = ChatViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatModel.messages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }
                            
                            if chatModel.isStreaming {
                                MessageView(message: ChatMessage(
                                    id: UUID(),
                                    text: chatModel.currentStreamingText,
                                    isUser: false,
                                    isStreaming: true
                                ))
                                .id("streaming")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatModel.messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo(chatModel.messages.last?.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: chatModel.currentStreamingText) { _ in
                        withAnimation {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }
                
                // Input area
                HStack {
                    TextField("Type your message...", text: $chatModel.inputText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(chatModel.isStreaming)
                    
                    Button("Send") {
                        chatModel.sendMessage()
                    }
                    .disabled(chatModel.inputText.isEmpty || chatModel.isStreaming)
                }
                .padding()
            }
            .navigationTitle("Claude Chat")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        chatModel.clearChat()
                    }
                }
            }
        }
        .alert("Error", isPresented: $chatModel.showError) {
            Button("OK") { }
        } message: {
            Text(chatModel.errorMessage)
        }
    }
}

struct MessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading) {
                Text(message.text)
                    .padding(12)
                    .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(12)
                
                if message.isStreaming {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.5)
                        Text("Claude is typing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity * 0.8, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let isStreaming: Bool
    
    init(id: UUID = UUID(), text: String, isUser: Bool, isStreaming: Bool = false) {
        self.text = text
        self.isUser = isUser
        self.isStreaming = isStreaming
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isStreaming = false
    @Published var currentStreamingText = ""
    @Published var showError = false
    @Published var errorMessage = ""
    
    private var client: AnthropicClient?
    
    init() {
        setupClient()
    }
    
    private func setupClient() {
        do {
            client = try AnthropicClient()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func sendMessage() {
        guard !inputText.isEmpty, let client = client else { return }
        
        let userMessage = ChatMessage(text: inputText, isUser: true)
        messages.append(userMessage)
        
        let messageToSend = inputText
        inputText = ""
        isStreaming = true
        currentStreamingText = ""
        
        Task {
            do {
                let stream = try await client.streamMessage(messageToSend)
                
                for try await chunk in stream {
                    switch chunk {
                    case .contentBlockDelta(let delta):
                        if case .textDelta(let text) = delta.delta {
                            currentStreamingText += text
                        }
                    case .messageStop:
                        let assistantMessage = ChatMessage(text: currentStreamingText, isUser: false)
                        messages.append(assistantMessage)
                        currentStreamingText = ""
                        isStreaming = false
                    case .error(let error):
                        showError(error.localizedDescription)
                        isStreaming = false
                    default:
                        break
                    }
                }
                
            } catch {
                showError(error.localizedDescription)
                isStreaming = false
            }
        }
    }
    
    func clearChat() {
        messages.removeAll()
        currentStreamingText = ""
        isStreaming = false
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
```

## iOS App Example

### Document Analyzer App

```swift
import SwiftUI
import AnthropicSDK
import UniformTypeIdentifiers

struct DocumentAnalyzerApp: App {
    var body: some Scene {
        WindowGroup {
            DocumentAnalyzerView()
        }
    }
}

struct DocumentAnalyzerView: View {
    @StateObject private var analyzer = DocumentAnalyzer()
    @State private var showingDocumentPicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if analyzer.isAnalyzing {
                    VStack {
                        ProgressView()
                        Text("Analyzing document...")
                            .foregroundColor(.secondary)
                    }
                } else if let analysis = analyzer.lastAnalysis {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Analysis Results")
                                .font(.title2)
                                .bold()
                            
                            Text(analysis)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        
                        Text("Select a document to analyze")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Button("Choose Document") {
                            showingDocumentPicker = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Document Analyzer")
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: [.pdf, .plainText, .rtf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        analyzer.analyzeDocument(at: url)
                    }
                case .failure(let error):
                    print("Error selecting document: \(error)")
                }
            }
        }
    }
}

@MainActor
class DocumentAnalyzer: ObservableObject {
    @Published var isAnalyzing = false
    @Published var lastAnalysis: String?
    
    private let client: AnthropicClient?
    
    init() {
        do {
            client = try AnthropicClient()
        } catch {
            client = nil
            print("Failed to initialize client: \(error)")
        }
    }
    
    func analyzeDocument(at url: URL) {
        guard let client = client else { return }
        
        isAnalyzing = true
        lastAnalysis = nil
        
        Task {
            do {
                // Load document data
                let data = try Data(contentsOf: url)
                let filename = url.lastPathComponent
                
                // Upload file
                let uploadRequest = FileUploadRequest(
                    file: data,
                    filename: filename,
                    contentType: contentType(for: url),
                    purpose: .document
                )
                
                let uploadResponse = try await client.files.upload(uploadRequest)
                
                // Analyze the document
                let response = try await client.messages.create(
                    model: .claude4Sonnet,
                    messages: [.user("""
                        Please analyze this document and provide:
                        1. A brief summary of the main content
                        2. Key findings or important points
                        3. Any recommendations or action items
                        4. Overall assessment of the document
                        """)],
                    maxTokens: 2000,
                    files: [FileReference(fileId: uploadResponse.file.id)]
                )
                
                if let text = response.content.first?.text {
                    lastAnalysis = text
                }
                
                // Clean up uploaded file
                try await client.files.delete(uploadResponse.file.id)
                
            } catch {
                lastAnalysis = "Error analyzing document: \(error.localizedDescription)"
            }
            
            isAnalyzing = false
        }
    }
    
    private func contentType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        case "rtf":
            return "application/rtf"
        default:
            return "application/octet-stream"
        }
    }
}
```

## macOS Command Line Tool

### AI-Powered Git Commit Generator

```swift
#!/usr/bin/env swift

import Foundation
import AnthropicSDK

@main
struct GitCommitGenerator {
    static func main() async {
        do {
            let client = try AnthropicClient()
            
            // Get git diff
            let gitDiff = try await runShellCommand("git diff --cached")
            
            guard !gitDiff.isEmpty else {
                print("No staged changes found. Stage some changes first with 'git add'.")
                return
            }
            
            print("🔍 Analyzing staged changes...")
            
            // Generate commit message
            let response = try await client.sendMessage(
                """
                Based on the following git diff, generate a concise, conventional commit message.
                Use the format: type(scope): description
                
                Types: feat, fix, docs, style, refactor, test, chore
                Keep the description under 50 characters.
                If there are multiple changes, focus on the most significant one.
                
                Git diff:
                \(gitDiff)
                """,
                model: .claude4Sonnet,
                maxTokens: 100
            )
            
            if let commitMessage = response.content.first?.text {
                let cleanMessage = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                
                print("\n💡 Suggested commit message:")
                print(cleanMessage)
                
                print("\nWould you like to use this commit message? (y/N): ", terminator: "")
                
                if let input = readLine(), input.lowercased().hasPrefix("y") {
                    try await runShellCommand("git commit -m \"\(cleanMessage)\"")
                    print("✅ Committed successfully!")
                } else {
                    print("Commit cancelled.")
                }
            }
            
        } catch AnthropicError.missingEnvironmentKey {
            print("❌ Please set ANTHROPIC_API_KEY environment variable")
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    static func runShellCommand(_ command: String) async throws -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.standardOutput = pipe
        process.standardError = pipe
        process.arguments = ["-c", command]
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
```

## Performance Tips

### Optimized Streaming with Batching

```swift
import AnthropicSDK

func optimizedStreamingExample() async {
    do {
        let client = try AnthropicClient(configuration: .mobile)
        
        let stream = try await client.streamMessage(
            "Write a detailed explanation of machine learning algorithms",
            model: .claude3_5Sonnet,
            maxTokens: 2000
        )
        
        var buffer = ""
        let bufferSize = 50 // Batch updates for better UI performance
        
        for try await chunk in stream {
            switch chunk {
            case .contentBlockDelta(let delta):
                if case .textDelta(let text) = delta.delta {
                    buffer += text
                    
                    // Update UI in batches for better performance
                    if buffer.count >= bufferSize {
                        await updateUI(with: buffer)
                        buffer = ""
                    }
                }
            case .messageStop:
                // Flush remaining buffer
                if !buffer.isEmpty {
                    await updateUI(with: buffer)
                }
                print("\nStreaming complete!")
            default:
                break
            }
        }
        
    } catch {
        print("Error: \(error)")
    }
}

@MainActor
func updateUI(with text: String) {
    // Update your UI here
    print(text, terminator: "")
}
```

These examples demonstrate the full capabilities of the Anthropic Swift SDK. For more detailed information, check out the [API Reference](api-reference.html) and explore the complete example projects in the GitHub repository.