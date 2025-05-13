import Foundation
import EagleFlow
import MCP

/// Manages connections to MCP servers
public class ConnectionManager {
    /// Collection of active EagleFlow instances
    private var connections: [String: EagleFlow] = [:]
    
    /// Create a new connection manager
    public init() {}
    
    /// Create and store a new connection with the given ID
    /// - Parameters:
    ///   - id: Unique identifier for this connection
    ///   - name: Client name
    ///   - version: Client version
    ///   - configuration: Client configuration
    /// - Returns: The created EagleFlow instance
    public func createConnection(
        id: String,
        name: String = "EagleFlow",
        version: String = "1.0.0",
        configuration: Client.Configuration = .default
    ) -> EagleFlow {
        let eagleFlow = EagleFlow(name: name, version: version, configuration: configuration)
        connections[id] = eagleFlow
        return eagleFlow
    }
    
    /// Get an existing connection by ID
    /// - Parameter id: The connection identifier
    /// - Returns: The EagleFlow instance if found, nil otherwise
    public func getConnection(id: String) -> EagleFlow? {
        return connections[id]
    }
    
    /// Remove a connection and disconnect if necessary
    /// - Parameter id: The connection identifier
    /// - Returns: true if the connection was found and removed
    @discardableResult
    public func removeConnection(id: String) async -> Bool {
        guard let connection = connections[id] else {
            return false
        }
        
        await connection.disconnect()
        connections.removeValue(forKey: id)
        return true
    }
    
    /// Get all active connection IDs
    /// - Returns: Array of connection identifiers
    public func listConnections() -> [String] {
        return Array(connections.keys)
    }
    
    /// Disconnect and remove all connections
    public func closeAllConnections() async {
        let ids = Array(connections.keys)
        for id in ids {
            await removeConnection(id: id)
        }
    }
}