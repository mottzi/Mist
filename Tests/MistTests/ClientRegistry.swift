import XCTest
@testable import Mist
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import WebSocketKit

final class ClientRegistry: XCTestCase
{
    override func setUp() async throws
    {
        // Reset singletons before each test
        await Mist.Clients.shared.resetForTesting()
    }
    
    // Tests server subscription message handling:
    // - message decoding - client storage integrity - connection verification - UUID matching
    func testClientComponentSubscription() async
    {
        // create test client
        let clientID = UUID()
        
        // create test json message
        let text = """
        {
            "type": "subscribe",
            "component": "TestComponent2"
        }
        """
        
        // use API to add test client to internal storage
        await Mist.Clients.shared.add(connection: clientID, socket: WebSocket.Dummy)
        
        // try to decode json message to mist message
        guard let data = text.data(using: .utf8) else { return XCTFail("Failed to convert JSON string to data") }
        guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return XCTFail("Failed to decode data to Mist message") }
        
        switch message
        {
            // ensure correct decoding
            case .subscribe(let component): do
            {
                // test correct decoding of component name
                XCTAssertEqual(component, "TestComponent2", "Mist message component should match JSON component string")
                
                // use API to add component name to client's subscription set
                await Mist.Clients.shared.addSubscription(component, for: clientID)
                
                // load internal storage
                let connections = await Mist.Clients.shared.connections
                
                // test internal storage
                XCTAssertEqual(connections.count, 1, "Only one client should exist")
                XCTAssertEqual(connections[0].id, clientID, "Client should exist")
                XCTAssert(connections[0].subscriptions.contains("TestComponent2"), "Client should be subscribed to component")
                XCTAssertEqual(connections[0].subscriptions.count, 1, "Client should have exactly one subscription")
            }
            
            // ensure correct decoding
            default: return XCTFail("Valid but non-subscribe message")
        }
    }
}

extension WebSocket
{
    static var Dummy: WebSocket
    {
        WebSocket(channel: EmbeddedChannel(loop: EmbeddedEventLoop()), type: PeerType.server)
    }
}
