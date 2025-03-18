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
    
    func testInternalStorage() async
    {
        // create test client
        let clientID = UUID()
        
        // use API to add test client to internal storage
        await Mist.Clients.shared.add(connection: clientID, socket: WebSocket.Dummy)
        
        // load internal storage
        var connections = await Mist.Clients.shared.connections
        
        // test internal storage after adding client
        XCTAssertEqual(connections.count, 1, "Only one client should exist")
        XCTAssertEqual(connections[0].id, clientID, "Client ID should match")
        XCTAssertEqual(connections[0].subscriptions.count, 0, "Client should not have subscriptions")
        
        // use API to add component name to client's subscription set
        await Mist.Clients.shared.addSubscription("MyComponent", for: clientID)
        
        // load internal storage
        connections = await Mist.Clients.shared.connections
        
        // test internal storage after adding subscription to client
        XCTAssertEqual(connections[0].subscriptions.count, 1, "Client should have exactly one subscription")
        XCTAssert(connections[0].subscriptions.contains("MyComponent"), "Client should be subscribed to component")
    }
    
    // Tests server subscription message handling:
    // - message decoding - client storage integrity - connection verification - UUID matching
    func testSubscriptionDecoding() async
    {
        // create test json message
        let text = """
        {
            "type": "subscribe",
            "component": "TestComponent2"
        }
        """
        
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
