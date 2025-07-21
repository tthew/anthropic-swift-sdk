import Foundation
import AnthropicSDK

/// Advanced tool use example demonstrating Claude's ability to use custom tools
///
/// This example shows:
/// - Defining custom tools with JSON schemas
/// - Tool execution handling
/// - Multi-turn conversations with tool results
/// - Error handling in tool execution

@main
struct ToolUseExample {
    static func main() async {
        do {
            let client = try AnthropicClient()
            
            print("🛠️ Anthropic Swift SDK - Tool Use Example")
            print("=" * 50)
            
            await demonstrateCalculatorTool(client)
            await demonstrateWeatherTool(client)
            await demonstrateMultipleTools(client)
            
        } catch {
            print("❌ Failed to initialize client: \(error)")
        }
    }
    
    /// Demonstrates a simple calculator tool
    private static func demonstrateCalculatorTool(_ client: AnthropicClient) async {
        print("\n🧮 Calculator Tool Example")
        print("-" * 30)
        
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
        
        do {
            let response = try await client.sendMessageWithTools(
                "What's 15 * 23 + 45 * 67?",
                tools: [calculatorTool],
                toolHandler: { toolName, input in
                    return await handleCalculatorTool(toolName: toolName, input: input)
                }
            )
            
            if let textContent = response.content.first,
               case .text(let text) = textContent {
                print("Final response: \(text)")
            }
            
        } catch {
            print("❌ Error with calculator tool: \(error)")
        }
    }
    
    /// Demonstrates a weather information tool
    private static func demonstrateWeatherTool(_ client: AnthropicClient) async {
        print("\n🌤️ Weather Tool Example")
        print("-" * 30)
        
        let weatherTool = Tool(
            name: "get_weather",
            description: "Gets current weather information for a specific location",
            inputSchema: [
                "type": "object",
                "properties": [
                    "location": [
                        "type": "string",
                        "description": "City and state/country (e.g., 'San Francisco, CA')"
                    ],
                    "unit": [
                        "type": "string",
                        "enum": ["celsius", "fahrenheit"],
                        "description": "Temperature unit preference"
                    ]
                ],
                "required": ["location"]
            ]
        )
        
        do {
            let response = try await client.sendMessageWithTools(
                "What's the weather like in Tokyo, Japan?",
                tools: [weatherTool],
                toolHandler: { toolName, input in
                    return await handleWeatherTool(toolName: toolName, input: input)
                }
            )
            
            if let textContent = response.content.first,
               case .text(let text) = textContent {
                print("Final response: \(text)")
            }
            
        } catch {
            print("❌ Error with weather tool: \(error)")
        }
    }
    
    /// Demonstrates using multiple tools in a single conversation
    private static func demonstrateMultipleTools(_ client: AnthropicClient) async {
        print("\n🔧 Multiple Tools Example")
        print("-" * 30)
        
        let tools = [
            Tool(
                name: "search_database",
                description: "Searches a product database for items",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "Search query for products"
                        ],
                        "category": [
                            "type": "string",
                            "enum": ["electronics", "clothing", "books", "home"],
                            "description": "Product category to search within"
                        ]
                    ],
                    "required": ["query"]
                ]
            ),
            Tool(
                name: "get_product_price",
                description: "Gets the current price of a specific product",
                inputSchema: [
                    "type": "object",
                    "properties": [
                        "product_id": [
                            "type": "string",
                            "description": "Unique product identifier"
                        ]
                    ],
                    "required": ["product_id"]
                ]
            )
        ]
        
        do {
            let response = try await client.sendMessageWithTools(
                "Find me wireless headphones under $100",
                tools: tools,
                toolHandler: { toolName, input in
                    return await handleMultipleTools(toolName: toolName, input: input)
                }
            )
            
            if let textContent = response.content.first,
               case .text(let text) = textContent {
                print("Final response: \(text)")
            }
            
        } catch {
            print("❌ Error with multiple tools: \(error)")
        }
    }
    
    // MARK: - Tool Handler Functions
    
    private static func handleCalculatorTool(toolName: String, input: [String: Any]) async -> String {
        guard toolName == "calculator" else {
            return "Unknown tool: \(toolName)"
        }
        
        guard let expression = input["expression"] as? String else {
            return "Error: Missing expression parameter"
        }
        
        print("🧮 Calculating: \(expression)")
        
        // Simple expression evaluator (in real app, use proper math library)
        let result = evaluateExpression(expression)
        let response = "The result of \(expression) is \(result)"
        
        print("📊 Calculator result: \(response)")
        return response
    }
    
    private static func handleWeatherTool(toolName: String, input: [String: Any]) async -> String {
        guard toolName == "get_weather" else {
            return "Unknown tool: \(toolName)"
        }
        
        guard let location = input["location"] as? String else {
            return "Error: Missing location parameter"
        }
        
        let unit = input["unit"] as? String ?? "celsius"
        
        print("🌤️ Getting weather for: \(location)")
        
        // Simulate weather API call (in real app, use actual weather service)
        let mockWeatherData = generateMockWeather(for: location, unit: unit)
        
        print("📡 Weather data retrieved: \(mockWeatherData)")
        return mockWeatherData
    }
    
    private static func handleMultipleTools(toolName: String, input: [String: Any]) async -> String {
        switch toolName {
        case "search_database":
            guard let query = input["query"] as? String else {
                return "Error: Missing query parameter"
            }
            let category = input["category"] as? String
            
            print("🔍 Searching database: \(query) in category: \(category ?? "all")")
            
            // Mock database search
            let results = mockDatabaseSearch(query: query, category: category)
            return "Found \(results.count) products: \(results.joined(separator: ", "))"
            
        case "get_product_price":
            guard let productId = input["product_id"] as? String else {
                return "Error: Missing product_id parameter"
            }
            
            print("💰 Getting price for product: \(productId)")
            
            // Mock price lookup
            let price = mockPriceLookup(productId: productId)
            return "Product \(productId) costs $\(price)"
            
        default:
            return "Unknown tool: \(toolName)"
        }
    }
    
    // MARK: - Helper Functions
    
    /// Simple expression evaluator (replace with proper math library in production)
    private static func evaluateExpression(_ expression: String) -> Double {
        // This is a very basic evaluator - use NSExpression or a proper math library
        let cleanExpression = expression.replacingOccurrences(of: " ", with: "")
        
        // Handle simple operations (this is just for demo purposes)
        if cleanExpression.contains("+") {
            let parts = cleanExpression.components(separatedBy: "+")
            return parts.compactMap { Double($0) }.reduce(0, +)
        } else if cleanExpression.contains("*") {
            let parts = cleanExpression.components(separatedBy: "*")
            return parts.compactMap { Double($0) }.reduce(1, *)
        }
        
        return Double(cleanExpression) ?? 0
    }
    
    /// Generate mock weather data
    private static func generateMockWeather(for location: String, unit: String) -> String {
        let temperatures = [18, 22, 25, 28, 15, 20, 26]
        let conditions = ["sunny", "cloudy", "rainy", "partly cloudy", "clear"]
        
        let temp = temperatures.randomElement() ?? 22
        let condition = conditions.randomElement() ?? "sunny"
        let unitSymbol = unit == "fahrenheit" ? "°F" : "°C"
        let displayTemp = unit == "fahrenheit" ? Int(Double(temp) * 9/5 + 32) : temp
        
        return "Current weather in \(location): \(displayTemp)\(unitSymbol), \(condition). Humidity: 65%, Wind: 12 km/h"
    }
    
    /// Mock database search
    private static func mockDatabaseSearch(query: String, category: String?) -> [String] {
        let products = [
            "Sony WH-1000XM4 Wireless Headphones",
            "Apple AirPods Pro (2nd Gen)",
            "Bose QuietComfort 35 II",
            "Sennheiser HD 660S",
            "Audio-Technica ATH-M50x"
        ]
        
        // Filter based on query (simple contains check)
        return products.filter { 
            $0.lowercased().contains(query.lowercased()) ||
            query.lowercased().contains("headphones") ||
            query.lowercased().contains("wireless")
        }
    }
    
    /// Mock price lookup
    private static func mockPriceLookup(productId: String) -> Double {
        let prices = [79.99, 89.99, 129.99, 199.99, 249.99, 299.99]
        return prices.randomElement() ?? 99.99
    }
}

// Helper extension
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}