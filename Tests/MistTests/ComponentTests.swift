import XCTest
@testable import Mist
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import WebSocketKit

final class ComponentTests: XCTestCase
{
    // Tests component registration:
    // - deduplication - model associations - component storage integrity - order preservation - model-based lookup
    func testComponentRegistration() async throws
    {
        // initialize test environment
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // register multiple components with dublicate
        let config = Mist.Configuration(app: app, components: [DummyRow1.self, DummyRow2.self, DummyRow1.self])
        await Mist.registerComponents(using: config)
        
        // verify model-based component registry lookup API
        let model1Components = await Mist.Components.shared.getComponents(for: DummyModel1.self)
        XCTAssertEqual(model1Components.count, 2, "Expected exactly 2 components for DummyModel1")
        XCTAssertEqual(model1Components[0].name, "DummyRow1", "First component should be 'DummyRow1'")
        XCTAssertEqual(model1Components[1].name, "DummyRow2", "Second component should be 'DummyRow2'")
        
        let model2Components = await Mist.Components.shared.getComponents(for: DummyModel2.self)
        XCTAssertEqual(model2Components.count, 1, "Expected exactly 1 component for DummyModel2")
        XCTAssertEqual(model2Components[0].name, "DummyRow1", "Only component should be 'DummyRow1'")
        
        // verify internal component registry
        let componentsArray = await Mist.Components.shared.testGetComponentsArray()
        XCTAssertEqual(componentsArray.count, 2, "Registry should contain exactly 1 component")
        XCTAssertEqual(componentsArray[0].name, "DummyRow1", "First component should be 'DummyRow1'")
        XCTAssertEqual(componentsArray[1].name, "DummyRow2", "Second component should be 'DummyRow2'")

        try await app.asyncShutdown()
    }
    
    // Tests server subscription message handling:
    // - message decoding - client storage integrity - connection verification - UUID matching
    func testSubscriptionMessageHandling() async
    {
        // create test client
        let clientID = UUID()
        
        // use API to add test client to internal storage
        await Mist.Clients.shared.add(connection: clientID, socket: WebSocket.makeDummy())
        
        // create test json message
        let text = """
        {
            "type": "subscribe",
            "component": "TestComponent2"
        }
        """
        
        // try to decode json message to mist message
        guard let data = text.data(using: .utf8) else { return XCTFail("Failed to convert JSON string to data") }
        guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return XCTFail("Failed to decode data to message") }
        
        switch message
        {
            // if message is subscribe message
            case .subscribe(let component): do
            {
                XCTAssertEqual(component, "TestComponent2", "Component should match message")

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
            
            default: return XCTFail("Valid but non-subscribe message")
        }
    }
}

extension WebSocket
{
    static func makeDummy() -> WebSocket
    {
        WebSocket(channel: EmbeddedChannel(loop: EmbeddedEventLoop()), type: PeerType.server)
    }
}

struct DummyRow1: Mist.Component
{
    static let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
}

struct DummyRow2: Mist.Component
{
    static let models: [any Mist.Model.Type] = [DummyModel1.self]
}

final class DummyModel1: Mist.Model, Content, @unchecked Sendable
{
    static let schema = "dummymodels"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "text") var text: String
    @Timestamp(key: "created", on: .create) var created: Date?
    
    init() {}
    
    init(text: String)
    {
        self.text = text
    }
}

final class DummyModel2: Mist.Model, Content, @unchecked Sendable
{
    static let schema = "dummymodels2"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "text2") var text2: String
    @Timestamp(key: "created", on: .create) var created: Date?
    
    init() {}
    
    init(text: String)
    {
        self.text2 = text
    }
}
