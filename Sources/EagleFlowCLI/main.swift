import Foundation
import EagleFlow
import EagleFlowUtils
import MCP

/// Simple command-line interface for EagleFlow
func main() async {
    print("EagleFlow CLI")
    print("=============")
    
    // Parse command-line arguments
    let args = CommandLine.arguments
    
    if args.count < 2 {
        printUsage()
        exit(1)
    }
    
    let command = args[1]
    
    do {
        switch command {
        case "list-tools":
            try await listTools()
            
        case "list-prompts":
            try await listPrompts()
            
        case "call-tool":
            if args.count < 3 {
                print("Error: Missing tool name")
                printUsage()
                exit(1)
            }
            let toolName = args[2]
            try await callTool(name: toolName)
            
        default:
            print("Unknown command: \(command)")
            printUsage()
            exit(1)
        }
    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }
}

/// Print CLI usage information
func printUsage() {
    print("Usage: EagleFlowCLI <command> [arguments]")
    print("")
    print("Commands:")
    print("  list-tools              List available tools")
    print("  list-prompts            List available prompts")
    print("  call-tool <tool-name>   Call a specific tool")
    print("")
}

/// List all available tools
func listTools() async throws {
    let eagleFlow = EagleFlow(name: "EagleFlowCLI", version: "1.0.0")
    let transport = StdioTransport()
    
    print("Connecting to MCP server...")
    let initResult = try await eagleFlow.connect(transport: transport)
    print("Connected to \(initResult.serverInfo.name) v\(initResult.protocolVersion)")
    
    print("Fetching available tools...")
    let (tools, _) = try await eagleFlow.listTools()
    
    print(ContentFormatter.formatTools(tools))
    
    await eagleFlow.disconnect()
}

/// List all available prompts
func listPrompts() async throws {
    let eagleFlow = EagleFlow(name: "EagleFlowCLI", version: "1.0.0")
    let transport = StdioTransport()
    
    print("Connecting to MCP server...")
    let initResult = try await eagleFlow.connect(transport: transport)
    print("Connected to \(initResult.serverInfo.name) v\(initResult.protocolVersion)")
    
    print("Fetching available prompts...")
    let (prompts, _) = try await eagleFlow.listPrompts()
    
    print(ContentFormatter.formatPrompts(prompts))
    
    await eagleFlow.disconnect()
}

/// Call a specific tool
func callTool(name: String) async throws {
    let eagleFlow = EagleFlow(name: "EagleFlowCLI", version: "1.0.0")
    let transport = StdioTransport()
    
    print("Connecting to MCP server...")
    let initResult = try await eagleFlow.connect(transport: transport)
    print("Connected to \(initResult.serverInfo.name) v\(initResult.protocolVersion)")
    
    print("Calling tool: \(name)...")
    let (content, isError) = try await eagleFlow.callTool(name: name)
    
    if let isError = isError, isError {
        print("Tool execution failed!")
    }
    
    print(ContentFormatter.formatContent(content))
    
    await eagleFlow.disconnect()
}

// Run the main function
Task {
    await main()
    exit(0)
}

// Keep the program running until the task completes
dispatchMain()