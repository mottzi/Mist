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
    
    // tests integrated subscription message flow: client -> server -> internal storage registry
    func testSubscriptionFlow() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register multiple components with dublicate
        let config = Mist.Configuration(app: app, components: [DumbComp4133.self])
        await Mist.registerComponents(using: config)
        
        // test this client message
        let message = #"{ "type": "subscribe", "component": "DumbComp4133" }"#
        
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
                print("*** client sending subscription message: \(message)")
                
                // send component subscription message to client -> server
                ws.send(message)
            }
        }
        
        try await app.asyncShutdown()
    }
    
    func testComponentUpdateFlow() async throws
    {
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        app.migrations.add(
            DummyModel1.Table(),
            DummyModel2.Table())
        
        try await app.autoMigrate()
        
        // register multiple components with dublicate
        let config = Mist.Configuration(app: app, components: [DumbComp4133.self])
        await Mist.registerComponents(using: config)
        
        let subMessage = #"{ "type": "subscribe", "component": "DumbComp4133" }"#

        let updateMessage =
        """
        {
            "type": "componentUpdate",
            "component": "DummyRow",
            "action": "update",
            "id": "F05F5571-A4D4-4227-B3D2-96B65BA9824A",
            "html": "<tr class="hover:bg-gray-50 dark:hover:bg-neutral-750 transition-colors duration-150" mist-component="DummyRow" mist-id="123e4567-e89b-12d3-a456-426614174000">
            <td class="px-6 py-4"><span class="font-mono text-indigo-600 dark:text-indigo-400 text-sm">F05F5571-A4D4-4227-B3D2-96B65BA9824A</span>
            </td>
            
            <td class="px-6 py-4 max-w-[160px]">
            <span class="block text-sm text-gray-700 dark:text-neutral-300 truncate font-medium">Some updated text value</span>
            </td>
            
            <td class="px-6 py-4">
            <span class="text-sm text-gray-700 dark:text-neutral-300 font-medium">Secondary model updated value</span>
            </td>
            </tr>"
        }
        """
        
        let updateModelID = "F05F5571-A4D4-4227-B3D2-96B65BA9824A"
        
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
                XCTAssertEqual(text, subMessage, "Sent and received message should match")
                
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
                        
                        // immediately after subscription
                       
                        // test component update message server -> client
                        
                        // get type-safe components registered for this model type
                        let components = await Mist.Components.shared.getComponents(for: DummyModel2.self)
                        
                        print("*** server sending update message...")
                        
                        try? await ws.send(updateMessage)
                    }
                        
                        // ensure correct decoding
                    default: return XCTFail("Valid but non-subscribe message")
                }
            }
        }
        
        // start server (will block indefinitly and cause timeout, that's fine atm)
        try await app.startup()
        
        // create test models for DumbComp4133
        let id = UUID()
        let m1 = DummyModel1(id: id, text: "Init")
        let m2 = DummyModel2(id: id, text2: "init")
                
        try await m1.save(on: app.db)
        try await m2.save(on: app.db)
        
        // client connects to server socket
        try await WebSocket.connect(to: "ws://localhost:8080/socket")
        { ws in
            Task
            {
                print("*** client sending subscription message: \(subMessage)")
                
                // send component subscription message to client -> server
                ws.send(subMessage)
                
                ws.onText()
                { ws, text async in
                    print("*** client receiving message: \(text)")
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
