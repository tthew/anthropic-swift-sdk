import Foundation
import AnthropicSDK

/// Comprehensive batch processing example
///
/// This example demonstrates:
/// - Creating batch requests for bulk processing
/// - Monitoring batch progress and status
/// - Retrieving and processing batch results  
/// - Handling batch errors and failures
/// - Performance optimization strategies

@main
struct BatchProcessingExample {
    static func main() async {
        do {
            let client = try AnthropicClient()
            
            print("📦 Anthropic Swift SDK - Batch Processing Example")
            print("=" * 60)
            
            await demonstrateBasicBatchProcessing(client)
            await demonstrateBatchStatusMonitoring(client)
            await demonstrateLargeBatchHandling(client)
            
        } catch {
            print("❌ Failed to initialize client: \(error)")
        }
    }
    
    /// Basic batch processing with a small set of requests
    private static func demonstrateBasicBatchProcessing(_ client: AnthropicClient) async {
        print("\n📋 Basic Batch Processing")
        print("-" * 40)
        
        // Create sample batch requests
        let requests = [
            BatchRequest(
                customId: "sentiment_1",
                method: .POST,
                url: "/v1/messages",
                body: CreateMessageRequest(
                    model: .claude3_5Sonnet,
                    messages: [.user("Analyze the sentiment of: 'I love this product!'")],
                    maxTokens: 50
                )
            ),
            BatchRequest(
                customId: "sentiment_2",
                method: .POST,
                url: "/v1/messages",
                body: CreateMessageRequest(
                    model: .claude3_5Sonnet,
                    messages: [.user("Analyze the sentiment of: 'This is terrible quality.'")],
                    maxTokens: 50
                )
            ),
            BatchRequest(
                customId: "summary_1",
                method: .POST,
                url: "/v1/messages",
                body: CreateMessageRequest(
                    model: .claude3_5Sonnet,
                    messages: [.user("Summarize: 'Machine learning is transforming industries by enabling computers to learn from data without explicit programming.'")],
                    maxTokens: 100
                )
            )
        ]
        
        do {
            print("🚀 Submitting batch with \(requests.count) requests...")
            
            let batch = try await client.batches.create(
                CreateBatchRequest(requests: requests)
            )
            
            print("✅ Batch created: \(batch.id)")
            print("   Status: \(batch.processingStatus)")
            print("   Total requests: \(batch.requestCounts.total)")
            
            // Wait for completion and get results
            let results = try await waitForBatchCompletion(client, batchId: batch.id)
            
            print("\n📊 Processing Results:")
            for result in results {
                print("   \(result.customId): \(result.isSuccess ? "✅ Success" : "❌ Failed")")
                
                if result.isSuccess, let response = result.result.response {
                    if let textContent = response.content.first,
                       case .text(let text) = textContent {
                        print("      → \(text.prefix(100))...")
                    }
                } else if let error = result.result.error {
                    print("      → Error: \(error.message)")
                }
            }
            
        } catch {
            print("❌ Batch processing error: \(error)")
        }
    }
    
    /// Demonstrates comprehensive batch status monitoring
    private static func demonstrateBatchStatusMonitoring(_ client: AnthropicClient) async {
        print("\n📊 Batch Status Monitoring")
        print("-" * 40)
        
        // Create a larger batch to demonstrate monitoring
        let requests = generateAnalysisRequests(count: 10)
        
        do {
            let batch = try await client.batches.create(
                CreateBatchRequest(requests: requests, metadata: ["type": "analysis_batch"])
            )
            
            print("📦 Created batch: \(batch.id)")
            
            // Monitor progress with detailed status updates
            var currentBatch = batch
            while !currentBatch.isCompleted {
                let counts = currentBatch.requestCounts
                let progress = counts.total > 0 ? 
                    Double(counts.succeeded + counts.errored + counts.cancelled) / Double(counts.total) * 100 : 0
                
                print("📈 Progress: \(String(format: "%.1f", progress))% " +
                      "(\(counts.succeeded) ✅, \(counts.errored) ❌, \(counts.processing) 🔄)")
                
                if let timeRemaining = currentBatch.timeUntilExpiration {
                    let minutes = Int(timeRemaining / 60)
                    print("   ⏰ Time until expiration: \(minutes) minutes")
                }
                
                // Wait before checking again
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                
                currentBatch = try await client.batches.retrieve(batch.id)
            }
            
            print("🎉 Batch completed!")
            print("   Final status: \(currentBatch.processingStatus)")
            print("   Success rate: \(String(format: "%.1f", currentBatch.requestCounts.successRate * 100))%")
            
            if currentBatch.hasResults {
                let results = try await client.batches.results(batch.id)
                print("   Retrieved \(results.data.count) results")
            }
            
        } catch {
            print("❌ Monitoring error: \(error)")
        }
    }
    
    /// Demonstrates handling large batches with chunking
    private static func demonstrateLargeBatchHandling(_ client: AnthropicClient) async {
        print("\n🚛 Large Batch Handling")
        print("-" * 40)
        
        // Simulate a large dataset that needs chunking
        let totalRequests = 25 // In practice, this might be thousands
        let chunkSize = 10     // Keep chunks manageable
        
        print("📊 Processing \(totalRequests) requests in chunks of \(chunkSize)...")
        
        var allResults: [BatchResult] = []
        var chunkIndex = 0
        
        for chunk in generateAnalysisRequests(count: totalRequests).chunked(into: chunkSize) {
            chunkIndex += 1
            print("\n📦 Processing chunk \(chunkIndex) (\(chunk.count) requests)...")
            
            do {
                let chunkBatch = try await client.batches.create(
                    CreateBatchRequest(
                        requests: chunk,
                        metadata: ["chunk": "\(chunkIndex)", "total_chunks": "\((totalRequests + chunkSize - 1) / chunkSize)"]
                    )
                )
                
                let chunkResults = try await waitForBatchCompletion(client, batchId: chunkBatch.id)
                allResults.append(contentsOf: chunkResults)
                
                let successCount = chunkResults.filter(\.isSuccess).count
                print("   ✅ Chunk \(chunkIndex) completed: \(successCount)/\(chunk.count) successful")
                
            } catch {
                print("   ❌ Chunk \(chunkIndex) failed: \(error)")
                continue // Continue with next chunk
            }
        }
        
        // Summary statistics
        let totalSuccess = allResults.filter(\.isSuccess).count
        let totalFailed = allResults.count - totalSuccess
        let overallSuccessRate = allResults.isEmpty ? 0 : Double(totalSuccess) / Double(allResults.count) * 100
        
        print("\n📈 Overall Results:")
        print("   Total processed: \(allResults.count)")
        print("   Successful: \(totalSuccess)")
        print("   Failed: \(totalFailed)")
        print("   Success rate: \(String(format: "%.1f", overallSuccessRate))%")
    }
    
    // MARK: - Helper Functions
    
    /// Waits for batch completion and returns results
    private static func waitForBatchCompletion(_ client: AnthropicClient, batchId: String) async throws -> [BatchResult] {
        var batch = try await client.batches.retrieve(batchId)
        
        while !batch.isCompleted {
            try await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
            batch = try await client.batches.retrieve(batchId)
        }
        
        if batch.hasResults {
            let results = try await client.batches.results(batchId)
            return results.data
        } else {
            throw BatchError(type: "no_results", message: "Batch completed but no results available")
        }
    }
    
    /// Generates sample analysis requests for testing
    private static func generateAnalysisRequests(count: Int) -> [BatchRequest] {
        let sampleTexts = [
            "The new iPhone features an impressive camera system with advanced computational photography.",
            "Climate change poses significant challenges that require immediate global action and cooperation.",
            "Artificial intelligence is revolutionizing healthcare through diagnostic imaging and personalized medicine.",
            "The stock market showed volatility this week amid concerns about inflation and interest rates.",
            "Renewable energy sources like solar and wind are becoming increasingly cost-effective alternatives.",
            "Remote work has fundamentally changed how teams collaborate and communicate in modern organizations.",
            "Quantum computing promises to solve complex problems that are intractable for classical computers.",
            "Social media platforms are implementing new policies to combat misinformation and protect user privacy.",
            "Electric vehicles are gaining mainstream adoption as battery technology continues to improve.",
            "The latest breakthrough in gene therapy offers hope for treating previously incurable genetic disorders."
        ]
        
        let analysisTypes = [
            "Analyze the sentiment and key themes",
            "Summarize the main points in 50 words",
            "Identify the primary subject and key insights",
            "Extract the most important keywords and concepts",
            "Determine the tone and intended audience"
        ]
        
        var requests: [BatchRequest] = []
        
        for i in 0..<count {
            let textIndex = i % sampleTexts.count
            let analysisIndex = i % analysisTypes.count
            let text = sampleTexts[textIndex]
            let analysisType = analysisTypes[analysisIndex]
            
            let request = BatchRequest(
                customId: "analysis_\(i + 1)",
                method: .POST,
                url: "/v1/messages",
                body: CreateMessageRequest(
                    model: .claude3_5Sonnet,
                    messages: [.user("\(analysisType): '\(text)'")],
                    maxTokens: 150
                )
            )
            
            requests.append(request)
        }
        
        return requests
    }
}

// MARK: - Extensions

extension Array {
    /// Splits array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

/// Custom error for batch operations
struct BatchError: Error {
    let type: String
    let message: String
}