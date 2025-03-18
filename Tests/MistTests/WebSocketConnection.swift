import XCTVapor
@testable import Mist
import Vapor
import Fluent
import FluentSQLiteDriver

final class WebSocketConnection: XCTestCase
{
    override func setUp() async throws
    {
        await Mist.Clients.shared.resetForTesting()
        await Mist.Components.shared.resetForTesting()
    }
    
    // Tests server subscription message handling:
    // - message decoding - client storage integrity - connection verification - UUID matching
    func testClientSubscriptionDecoding() async
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
    
    func testClientSubscriptionOverSocket() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register multiple components with dublicate
        let config = Mist.Configuration(app: app, components: [])
        await Mist.registerComponents(using: config)
        
        // test this message
        let message = #"{ "type": "subscribe", "component": "DumbComp4133" }"#
        
        // set up websocket on server
        app.webSocket("socket")
        { request, ws async in
            
            // create client
            let clientID = UUID()
            
            // use API to add client to internal storage (tested in ClientRegistry.testInternalStorage()
            await Mist.Clients.shared.add(connection: clientID, socket: ws)
            
            // get internal storage
            let connections = await Mist.Clients.shared.connections
            
            // test internal storage after adding client
            XCTAssertEqual(connections.count, 1, "Only one client should exist")
            XCTAssertEqual(connections[0].id, clientID, "Client ID should match")
            XCTAssertEqual(connections[0].subscriptions.count, 0, "Client should not have subscriptions")
            
            ws.onText()
            { ws, text async in
                print("*** server receiving message: \(text)")
                
                // make sure sent client message and received server message match
                XCTAssertEqual(text, message, "Sent and received message should match")
                
                // try to decode json message to typed mist message
                guard let data = text.data(using: .utf8) else { return XCTFail("Failed to convert JSON string to data") }
                guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return XCTFail("Failed to decode data to Mist message") }
                
                switch message
                {
                    // ensure correct decoding
                    case .subscribe(let component): do
                    {
                        // test correct decoding of component name
                        XCTAssertEqual(component, "DumbComp4133", "Mist message component should match JSON component string")
                        
                        // use API to add client sent component name to client's subscription set
                        await Mist.Clients.shared.addSubscription(component, for: clientID)

                        // get internal storage
                        let connections = await Mist.Clients.shared.connections
                        
                        // test internal storage after adding subscription
                        XCTAssertEqual(connections.count, 1, "Only one client should exist")
                        XCTAssertEqual(connections[0].subscriptions.count, 1, "Client should have exactly one subscription")
                        XCTAssert(connections[0].subscriptions.contains("DumbComp4133"), "Client should be subscribed to component")
                    }
                        
                    // ensure correct decoding
                    default: return XCTFail("Valid but non-subscribe message")
                }
            }
        }
        
        // start server (will block indefinitly and cause timeout, that's fine atm)
        try await app.startup()
        
        // connect client to server websocket
        try await WebSocket.connect(to: "ws://localhost:8080/socket")
        { ws in
            Task
            {
                print("*** client sending subscription message: \(message)")
                
                // make client send component subscription message to server
                ws.send(message)
            }
        }
            
        try await app.asyncShutdown()
    }
}
