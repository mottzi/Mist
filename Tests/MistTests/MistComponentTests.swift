import XCTest
import Vapor
import Fluent
import Leaf
import FluentSQLiteDriver
@testable import Mist

final class MistComponentTest: XCTestCase
{
    override func setUp() async throws
    {
        // reset singletons before each test
        await Mist.Clients.shared.resetForTesting()
        await Mist.Components.shared.resetForTesting()
    }
    
    func testMakeContextSingle() async throws
    {
        // set up application and database
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        
        // add migrations
        app.migrations.add(DummyModel1.Table(), DummyModel2.Table())
        try await app.autoMigrate()
        
        // configure mist with our test component
        let config = Mist.Configuration(app: app, components: [MyComponent.self], testing: true)
        await Mist.registerComponents(using: config)
        
        // Start the server
        try await app.startup()
        
        // create a model ID that we'll use for testing
        guard let modelID = UUID(uuidString: "3D8965CD-C57D-49D2-A1F2-8EE8964DAF72") else { return XCTFail("Could not create UUID") }
        
        let model1 = DummyModel1(id: modelID, text: "Initial text")
        let model2 = DummyModel2(id: modelID, text2: "Initial text 2")
        
        // save models to database
        try await model1.save(on: app.db)
        try await model2.save(on: app.db)

        guard let context = await MyComponent.makeContext(of: modelID, in: app.db) else { return XCTFail("No context") }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let jsonData = try? encoder.encode(context.component),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            print(jsonString)
        }
        
        // decode component to a dictionary for assertions
        guard let jsonData = try? JSONEncoder().encode(context.component),
              let component = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else
        {
            XCTFail("Could not decode component to dictionary")
            return
        }
        
        // verify both models exist in component
        XCTAssertNotNil(component["dummymodel1"], "DummyModel1 should exist in component")
        XCTAssertNotNil(component["dummymodel2"], "DummyModel2 should exist in component")
        
        // verify DummyModel1 properties
        guard let dummyModel1 = component["dummymodel1"] as? [String: Any] else
        {
            XCTFail("Could not extract DummyModel1 from component")
            return
        }
        
        XCTAssertEqual(dummyModel1["id"] as? String, "3D8965CD-C57D-49D2-A1F2-8EE8964DAF72", "DummyModel1 ID should match expected value")
        XCTAssertEqual(dummyModel1["text"] as? String, "Initial text", "DummyModel1 text should match updated value")
        XCTAssertNotNil(dummyModel1["created"], "DummyModel1 created timestamp should exist")
        
        // verify DummyModel2 properties
        guard let dummyModel2 = component["dummymodel2"] as? [String: Any] else
        {
            XCTFail("Could not extract DummyModel2 from component")
            return
        }
        
        XCTAssertEqual(dummyModel2["id"] as? String, "3D8965CD-C57D-49D2-A1F2-8EE8964DAF72", "DummyModel2 ID should match expected value")
        XCTAssertEqual(dummyModel2["text2"] as? String, "Initial text 2", "DummyModel2 text2 should match initial value")
        XCTAssertNotNil(dummyModel2["created"], "DummyModel2 created timestamp should exist")
        
        // verify that both models share the same ID
        XCTAssertEqual(dummyModel1["id"] as? String, dummyModel2["id"] as? String, "Both models should have the same ID")
    }
}

struct MyComponent: Mist.Component
{
    static let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
    
    
}

