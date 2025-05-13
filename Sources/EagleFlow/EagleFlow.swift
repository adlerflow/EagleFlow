import Foundation
import MCP

/// Main EagleFlow class for AI workflow management using MCP
public class EagleFlow {
    /// MCP client instance
    private let client: Client
    
    /// Initialize EagleFlow with configuration
    /// - Parameters:
    ///   - name: Client name
    ///   - version: Client version
    ///   - configuration: Client configuration (default is non-strict)
    public init(name: String = "EagleFlow", version: String = "1.0.0", configuration: Client.Configuration = .default) {
        self.client = Client(name: name, version: version, configuration: configuration)
    }
    
    /// Connect to an MCP server using the specified transport
    /// - Parameter transport: The transport to use for connection
    /// - Returns: Result of the initialization process
    public func connect(transport: any Transport) async throws -> Initialize.Result {
        try await client.connect(transport: transport)
        return try await client.initialize()
    }
    
    /// Disconnect from the MCP server
    public func disconnect() async {
        await client.disconnect()
    }
    
    /// Call a tool on the MCP server
    /// - Parameters:
    ///   - name: Tool name to call
    ///   - arguments: Arguments to pass to the tool
    /// - Returns: Tool execution result with content and error status
    public func callTool(name: String, arguments: [String: Value]? = nil) async throws -> (content: [Tool.Content], isError: Bool?) {
        return try await client.callTool(name: name, arguments: arguments)
    }
    
    /// List available tools on the MCP server
    /// - Parameter cursor: Optional pagination cursor
    /// - Returns: List of available tools and optional next cursor
    public func listTools(cursor: String? = nil) async throws -> (tools: [Tool], nextCursor: String?) {
        return try await client.listTools(cursor: cursor)
    }
    
    /// List available prompts on the MCP server
    /// - Parameter cursor: Optional pagination cursor
    /// - Returns: List of available prompts and optional next cursor
    public func listPrompts(cursor: String? = nil) async throws -> (prompts: [Prompt], nextCursor: String?) {
        return try await client.listPrompts(cursor: cursor)
    }
    
    /// Get a prompt from the MCP server
    /// - Parameters:
    ///   - name: Prompt name
    ///   - arguments: Arguments to instantiate the prompt
    /// - Returns: Prompt description and messages
    public func getPrompt(name: String, arguments: [String: Value]? = nil) async throws -> (description: String?, messages: [Prompt.Message]) {
        return try await client.getPrompt(name: name, arguments: arguments)
    }
}