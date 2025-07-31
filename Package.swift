// swift-tools-version: 5.9.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AnthropicSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        // The main SDK library
        .library(
            name: "AnthropicSDK",
            targets: ["AnthropicSDK"]
        ),
        // Example executables for demonstration
        .executable(
            name: "BasicChatExample",
            targets: ["BasicChatExample"]
        ),
        .executable(
            name: "ToolUseExample", 
            targets: ["ToolUseExample"]
        ),
        .executable(
            name: "BatchProcessingExample",
            targets: ["BatchProcessingExample"]
        ),
        .executable(
            name: "FileAnalysisExample",
            targets: ["FileAnalysisExample"]
        )
    ],
    dependencies: [
        // Zero external dependencies - Foundation only approach
        // This ensures maximum compatibility and minimal attack surface
    ],
    targets: [
        // Main SDK target
        .target(
            name: "AnthropicSDK",
            dependencies: []
        ),
        
        // Comprehensive test suite
        .testTarget(
            name: "AnthropicSDKTests",
            dependencies: ["AnthropicSDK"]
        ),
        
        // Example targets (require AnthropicSDK)
        .executableTarget(
            name: "BasicChatExample",
            dependencies: ["AnthropicSDK"],
            path: "Examples",
            exclude: ["ToolUseExample.swift", "BatchProcessingExample.swift", "FileAnalysisExample.swift"],
            sources: ["BasicChatExample.swift"]
        ),
        .executableTarget(
            name: "ToolUseExample",
            dependencies: ["AnthropicSDK"],
            path: "Examples",
            exclude: ["BasicChatExample.swift", "BatchProcessingExample.swift", "FileAnalysisExample.swift"],
            sources: ["ToolUseExample.swift"]
        ),
        .executableTarget(
            name: "BatchProcessingExample",
            dependencies: ["AnthropicSDK"],
            path: "Examples",
            exclude: ["BasicChatExample.swift", "ToolUseExample.swift", "FileAnalysisExample.swift"],
            sources: ["BatchProcessingExample.swift"]
        ),
        .executableTarget(
            name: "FileAnalysisExample", 
            dependencies: ["AnthropicSDK"],
            path: "Examples",
            exclude: ["BasicChatExample.swift", "ToolUseExample.swift", "BatchProcessingExample.swift"],
            sources: ["FileAnalysisExample.swift"]
        )
    ],
    swiftLanguageVersions: [.v5]
)