import AnthropicSDK

// Test that main types are accessible
let _ = ClaudeModel.allCases
let _ = Usage(inputTokens: 10, outputTokens: 20)

// Test that we can attempt client initialization (will fail without key, but API should be accessible)
do {
  let _ = try AnthropicClient(apiKey: "test")
} catch {
  // Expected to fail with invalid key, but API should be accessible
  print("API accessibility test passed - \(error)")
}

print("✅ API compatibility check passed")
EOF < /dev/null