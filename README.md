# EagleFlow

A Swift package that integrates with the Model Context Protocol (MCP) to provide AI workflow management.

## Overview

EagleFlow is a convenience wrapper around the MCP Swift SDK that simplifies working with AI models through the standardized Model Context Protocol. It provides an easy-to-use API for connecting to MCP servers, calling tools, and working with resources and prompts.

## Project Structure

This project contains three main components:

1. **EagleFlow**: The core library that wraps the MCP Swift SDK
2. **EagleFlowUtils**: Utility functions for formatting output and managing connections
3. **EagleFlowCLI**: A command-line interface for interacting with MCP servers

## Requirements

- Swift 6.0+ (Xcode 16+)
- Platforms: macOS 13.0+, iOS 16.0+, tvOS 16.0+, watchOS 9.0+, visionOS 1.0+

## Getting Started

### Opening in Xcode

You can open the project in Xcode by running:

```bash
./open_in_xcode.sh
```

Or by directly opening the Package.swift file in Xcode.

### Building from Command Line

```bash
swift build
```

This will build all targets, including the EagleFlowCLI executable.

### Running the CLI

```bash
.build/debug/EagleFlowCLI list-tools
.build/debug/EagleFlowCLI list-prompts
.build/debug/EagleFlowCLI call-tool <tool-name>
```

## Installation in Your Project

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/EagleFlow.git", from: "1.0.0")
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "EagleFlow", package: "EagleFlow")
    ]
)
```

## Library Usage

```swift
import EagleFlow
import MCP

// Initialize EagleFlow
let eagleFlow = EagleFlow(name: "MyApp", version: "1.0.0")

// Create a transport and connect
let transport = StdioTransport()
let result = try await eagleFlow.connect(transport: transport)

// Check server capabilities
if result.capabilities.tools != nil {
    // Server supports tools
    let tools = try await eagleFlow.listTools()
    print("Available tools: \(tools.map { $0.name }.joined(separator: ", "))")

    // Call a tool
    let (content, isError) = try await eagleFlow.callTool(
        name: "example-tool",
        arguments: ["param": "value"]
    )

    // Process tool results
    for item in content {
        switch item {
        case .text(let text):
            print("Text response: \(text)")
        case .image(let data, let mimeType, _):
            print("Received image of type \(mimeType)")
        // Handle other content types...
        }
    }
}

// Disconnect when done
await eagleFlow.disconnect()
```

## Utilities Usage

```swift
import EagleFlowUtils
import EagleFlow
import MCP

// Create a connection manager
let manager = ConnectionManager()

// Create and store a connection
let eagleFlow = manager.createConnection(id: "primary")

// Format tool content for display
let formattedContent = ContentFormatter.formatContent(toolContent)
print(formattedContent)
```

## License

This project is licensed under the MIT License. See the [LICENSE.txt](LICENSE.txt) file for details.