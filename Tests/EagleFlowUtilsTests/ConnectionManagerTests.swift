import XCTest
@testable import EagleFlowUtils
@testable import EagleFlow

final class ConnectionManagerTests: XCTestCase {
    func testCreateConnection() {
        let manager = ConnectionManager()
        let connection = manager.createConnection(id: "test1", name: "TestApp", version: "1.0.0")
        
        XCTAssertNotNil(connection)
        
        let retrievedConnection = manager.getConnection(id: "test1")
        XCTAssertNotNil(retrievedConnection)
    }
    
    func testGetNonExistentConnection() {
        let manager = ConnectionManager()
        let connection = manager.getConnection(id: "nonexistent")
        
        XCTAssertNil(connection)
    }
    
    func testListConnections() {
        let manager = ConnectionManager()
        _ = manager.createConnection(id: "conn1")
        _ = manager.createConnection(id: "conn2")
        _ = manager.createConnection(id: "conn3")
        
        let connections = manager.listConnections()
        
        XCTAssertEqual(connections.count, 3)
        XCTAssertTrue(connections.contains("conn1"))
        XCTAssertTrue(connections.contains("conn2"))
        XCTAssertTrue(connections.contains("conn3"))
    }
    
    func testRemoveConnection() async {
        let manager = ConnectionManager()
        _ = manager.createConnection(id: "conn1")
        _ = manager.createConnection(id: "conn2")
        
        let result = await manager.removeConnection(id: "conn1")
        XCTAssertTrue(result)
        
        let connections = manager.listConnections()
        XCTAssertEqual(connections.count, 1)
        XCTAssertTrue(connections.contains("conn2"))
        XCTAssertFalse(connections.contains("conn1"))
    }
    
    func testCloseAllConnections() async {
        let manager = ConnectionManager()
        _ = manager.createConnection(id: "conn1")
        _ = manager.createConnection(id: "conn2")
        _ = manager.createConnection(id: "conn3")
        
        await manager.closeAllConnections()
        
        let connections = manager.listConnections()
        XCTAssertEqual(connections.count, 0)
    }
}