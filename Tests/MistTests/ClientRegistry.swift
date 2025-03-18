import XCTest
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import WebSocketKit
@testable import Mist

final class ClientRegistry: XCTestCase
{
    override func setUp() async throws
    {
        // reset singletons before each test
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
        
        // use testing API to register component without config (for listener creation
        await Mist.Components.shared.registerWithoutListenerForTesting(component: DummyRow1.self)
        
        // use API to add component name to client's subscription set
        let added = await Mist.Clients.shared.addSubscription("DummyRow1", to: clientID)
        XCTAssertEqual(added, true, "Component not found.")
        
        // load internal storage
        connections = await Mist.Clients.shared.connections
        
        // test internal storage after adding subscription to client
        XCTAssertEqual(connections.count, 1, "Only one client should exist")
        XCTAssertEqual(connections[0].subscriptions.count, 1, "Client should have exactly one subscription")
        XCTAssert(connections[0].subscriptions.contains("DummyRow1"), "Client should be subscribed to component")
    }
}

extension WebSocket
{
    static var Dummy: WebSocket
    {
        WebSocket(channel: EmbeddedChannel(loop: EmbeddedEventLoop()), type: PeerType.server)
    }
}
