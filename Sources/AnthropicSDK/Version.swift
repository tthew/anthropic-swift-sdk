import Foundation

/// Version information for the Anthropic Swift SDK
public struct SDKVersion {
    /// The current version of the SDK
    public static let current = "1.1.3"
    
    /// The commit hash of this release
    public static let commitHash = "a0d7078"
    
    /// Release date
    public static let releaseDate = "2025-07-21"
    
    /// Major features in this version
    public static let features = [
        "HOTFIX: Complete message_delta chunk support",
        "CRITICAL FIX: Corrected Claude 4 Model Identifiers",
        "MAJOR FIX: Enhanced Streaming Parser Resilience",
        "Claude 4 Opus & Sonnet Models", 
        "Hybrid Reasoning Support",
        "Complete Models Discovery API",
        "Enhanced Performance Optimizations"
    ]
    
    /// Checks if Claude 4 models are available in this version
    public static var hasClaude4Support: Bool {
        return ClaudeModel.allCases.contains { model in
            model.rawValue.contains("claude-4")
        }
    }
    
    /// Gets a summary of the current SDK version
    public static var summary: String {
        return """
        Anthropic Swift SDK v\(current)
        Commit: \(commitHash)
        Released: \(releaseDate)
        Claude 4 Support: \(hasClaude4Support ? "✅ Available" : "❌ Not Available")
        
        Available Models:
        \(ClaudeModel.allCases.map { "  - \($0.rawValue)" }.joined(separator: "\n"))
        
        Key Features:
        \(features.map { "  • \($0)" }.joined(separator: "\n"))
        """
    }
    
    /// Prints version information to console
    public static func printVersion() {
        print(summary)
    }
}