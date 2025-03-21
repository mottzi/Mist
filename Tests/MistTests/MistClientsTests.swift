import XCTest
import Vapor
import FluentSQLiteDriver
@testable import WebSocketKit
@testable import Mist

final class MistClientsTests: XCTestCase
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
        await Mist.Clients.shared.add(client: clientID, socket: WebSocket.dummy)
        
        // load internal storage
        var clients = await Mist.Clients.shared.clients
        
        // test internal storage after adding client
        XCTAssertEqual(clients.count, 1, "Only one client should exist")
        XCTAssertEqual(clients[0].id, clientID, "Client ID should match")
        XCTAssertEqual(clients[0].subscriptions.count, 0, "Client should not have subscriptions")
        
        // use testing API to register component without config (for listener creation
        await Mist.Components.shared.registerWithoutListenerForTesting(component: DummyRow1.self)
        
        // use API to add component name to client's subscription set
        let added = await Mist.Clients.shared.addSubscription("DummyRow1", to: clientID)
        XCTAssertEqual(added, true, "Component not found.")
        
        // load internal storage
        clients = await Mist.Clients.shared.clients
        
        // test internal storage after adding subscription to client
        XCTAssertEqual(clients.count, 1, "Only one client should exist")
        XCTAssertEqual(clients[0].subscriptions.count, 1, "Client should have exactly one subscription")
        XCTAssert(clients[0].subscriptions.contains("DummyRow1"), "Client should be subscribed to component")
    }
}

extension WebSocket
{
    static var dummy: WebSocket
    {
        WebSocket(channel: EmbeddedChannel(loop: EmbeddedEventLoop()), type: PeerType.server)
    }
}
