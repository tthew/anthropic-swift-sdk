import Foundation
import AnthropicSDK

/// Basic chat example demonstrating simple message sending and streaming
/// 
/// This example shows:
/// - Client initialization 
/// - Simple message sending
/// - Real-time streaming responses
/// - Basic error handling

@main
struct BasicChatExample {
    static func main() async {
        do {
            // Initialize the client (requires ANTHROPIC_API_KEY environment variable)
            let client = try AnthropicClient()
            
            print("🤖 Anthropic Swift SDK - Basic Chat Example")
            print("=" * 50)
            
            await demonstrateSimpleMessage(client)
            await demonstrateStreaming(client)
            
        } catch AnthropicError.missingEnvironmentKey {
            print("❌ Error: Please set ANTHROPIC_API_KEY environment variable")
            print("   export ANTHROPIC_API_KEY=sk-ant-your-api-key")
        } catch {
            print("❌ Failed to initialize client: \(error)")
        }
    }
    
    /// Demonstrates sending a simple text message
    private static func demonstrateSimpleMessage(_ client: AnthropicClient) async {
        print("\n📝 Simple Message Example")
        print("-" * 30)
        
        do {
            let response = try await client.sendMessage(
                "Write a haiku about Swift programming",
                model: .claude3_5Sonnet,
                maxTokens: 100
            )
            
            if let textContent = response.content.first,
               case .text(let text) = textContent {
                print("Claude's response:")
                print(text)
                print("\nToken usage: \(response.usage.inputTokens ?? 0) in, \(response.usage.outputTokens) out")
            }
            
        } catch {
            print("❌ Error sending message: \(error)")
        }
    }
    
    /// Demonstrates streaming responses for real-time interaction
    private static func demonstrateStreaming(_ client: AnthropicClient) async {
        print("\n🔄 Streaming Example")
        print("-" * 30)
        
        do {
            let stream = try await client.streamMessage(
                "Tell me an interesting fact about space exploration",
                model: .claude3_5Sonnet,
                maxTokens: 200
            )
            
            print("Claude's streaming response:")
            
            var fullResponse = ""
            for try await chunk in stream {
                switch chunk {
                case .messageStart:
                    print("🚀 Starting response...")
                    
                case .contentBlockStart:
                    print("📝 Content block started...")
                    
                case .contentBlockDelta(let deltaChunk):
                    let text = deltaChunk.delta.text
                    print(text, terminator: "")
                    fullResponse += text
                    
                case .contentBlockStop:
                    print("\n📋 Content block completed")
                    
                case .messageStop:
                    print("✅ Response complete!")
                    
                default:
                    break
                }
            }
            
            print("\nFull response length: \(fullResponse.count) characters")
            
        } catch {
            print("❌ Error in streaming: \(error)")
        }
    }
}

// Helper extension for string repetition
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}