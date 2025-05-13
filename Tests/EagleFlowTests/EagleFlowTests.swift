import XCTest
@testable import EagleFlow
import MCP

final class EagleFlowTests: XCTestCase {
    func testInitialization() {
        let eagleFlow = EagleFlow(name: "TestClient", version: "1.0.0")
        XCTAssertNotNil(eagleFlow)
    }
    
    // Additional tests would require mocking the MCP transport and server
}