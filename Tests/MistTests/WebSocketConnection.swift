import XCTVapor
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import Mist

final class WebSocketConnection: XCTestCase
{
    override func setUp() async throws
    {
        // reset singletons before each test
        await Mist.Clients.shared.resetForTesting()
        await Mist.Components.shared.resetForTesting()
    }
    
    // tests decoding json subscription message to Mist.Message type
    func testSubscriptionDecoding() async
    {
        // create test json message
        let text = #"{ "type": "subscribe", "component": "TestComponent2" }"#
        
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
    
    // tests integrated subscription message flow: client -> server -> internal storage registry
    func testSubscriptionFlow() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register multiple components with dublicate
        let config = Mist.Configuration(app: app, components: [DumbComp4133.self])
        await Mist.registerComponents(using: config)
        
        // test this client message
        let subscriptionMessage = #"{ "type": "subscribe", "component": "DumbComp4133" }"#
        
        // set up websocket on server
        app.webSocket("socket")
        { request, ws async in
            
            // create client
            let clientID = UUID()
            
            // use API to add client to internal storage
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
                XCTAssertEqual(text, subscriptionMessage, "Sent and received message should match")
                
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
                        let added = await Mist.Clients.shared.addSubscription(component, to: clientID)
                        XCTAssertEqual(added, true, "Component not found (or client)")

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
        
        // client connects to server socket
        try await WebSocket.connect(to: "ws://localhost:8080/socket")
        { ws in
            Task
            {
                print("*** client sending subscription message: \(subscriptionMessage)")
                
                // send component subscription message to client -> server
                ws.send(subscriptionMessage)
            }
        }
        
        try await app.asyncShutdown()
    }
    
    // tests integrated subscription message flow: client -> server -> internal storage registry
    // tests integrated update message flow: server -> client
    func testUpdateFlow() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register multiple components with dublicate
        let config = Mist.Configuration(app: app, components: [DumbComp4133.self])
        await Mist.registerComponents(using: config)
        
        let modelID = "F05F5571-A4D4-4227-B3D2-96B65BA9824A"
        
        let subscriptionMessage = #"{ "type": "subscribe", "component": "DumbComp4133" }"#
        
        let updateMessage =
        """
        {
            "type": "componentUpdate",
            "component": "DumbComp4133",
            "action": "update",
            "id": "\(modelID)",
            "html": "<div mist-component=\\"DumbComp4133\\" mist-id=\\"\(modelID)\\">New Content</div>"
        }
        """
                
        // set up websocket on server
        app.webSocket("socket")
        { request, ws async in
            
            // create client
            let clientID = UUID()
            
            // use API to add client to internal storage
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
                XCTAssertEqual(text, subscriptionMessage, "Sent and received message should match")
                
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
                        let added = await Mist.Clients.shared.addSubscription(component, to: clientID)
                        XCTAssertEqual(added, true, "Component not found (or client)")
                        
                        // get internal storage
                        let connections = await Mist.Clients.shared.connections
                        
                        // test internal storage after adding subscription
                        XCTAssertEqual(connections.count, 1, "Only one client should exist")
                        XCTAssertEqual(connections[0].subscriptions.count, 1, "Client should have exactly one subscription")
                        XCTAssert(connections[0].subscriptions.contains("DumbComp4133"), "Client should be subscribed to component")
                        
                        // after subscription, test component update
                        print("*** server sending message: \(updateMessage)")
                        try? await ws.send(updateMessage)
                    }
                        
                    // ensure correct decoding
                    default: return XCTFail("Valid but non-subscribe message")
                }
            }
        }
        
        // start server (will block indefinitly and cause timeout, that's fine atm)
        try await app.startup()
        
        // client connects to server socket
        try await WebSocket.connect(to: "ws://localhost:8080/socket")
        { ws in
            Task
            {
                print("*** client sending subscription message: \(subscriptionMessage)")
                
                // send component subscription message to client -> server
                ws.send(subscriptionMessage)
            }
            
            ws.onText()
            { ws, text in
                print("*** client receiving message: \(text)")
            
                // try to decode json message to typed mist message
                guard let data = text.data(using: .utf8) else { return XCTFail("Failed to convert JSON string to data") }
                guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return XCTFail("Failed to decode data to Mist message") }
                
                switch message
                {
                    case .componentUpdate(let component, _, let id, _): do
                    {
                        XCTAssertEqual(component, "DumbComp4133", "Update message for wrong component.")
                        XCTAssertEqual(id?.uuidString, modelID, "Update message for wrong component.")
                    }
                        
                    default: return XCTFail("Valid but non-update message")
                }
            }
        }
        
        try await app.asyncShutdown()
    }
}
    
struct DumbComp4133: Mist.Component
{
    static let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
}
