import XCTest
@testable import Mist
import Vapor
import Fluent
import FluentSQLiteDriver

final class ComponentTests: XCTestCase
{
    // Tests component registration:
    // - deduplication - model associations - registry integrity - order preservation - model-based lookup
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
