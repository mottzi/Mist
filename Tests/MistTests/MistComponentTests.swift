import XCTest
import Vapor
import Fluent
@testable import LeafKit
import FluentSQLiteDriver
@testable import Mist

struct MyComponent: Mist.Component
{
    static let models: [any Mist.Model.Type] = [DummyModel1.self, DummyModel2.self]
}

final class MistComponentTests: XCTestCase
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
        let config = Mist.Configuration(for: app, using: [MyComponent.self], testing: true)
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
        
        try await app.asyncShutdown()
    }
    
    func testRendering() async throws
    {
        // set up application and database
        let app = try await Application.make(.testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)
        app.migrations.add(DummyModel1.Table(), DummyModel2.Table())
        try await app.autoMigrate()
        let config = Mist.Configuration(for: app, using: [MyComponent.self], testing: true)
        await Mist.registerComponents(using: config)
        
        // Start the server
        try await app.startup()
        
        // fixed "component" id
        guard let modelID = UUID(uuidString: "3D8965CD-C57D-49D2-A1F2-8EE8964DAF72") else { return XCTFail("Could not create UUID") }
        
        // create model entries with fixed id
        let model1 = DummyModel1(id: modelID, text: "Hello")
        let model2 = DummyModel2(id: modelID, text2: "World")
        try await model1.save(on: app.db)
        try await model2.save(on: app.db)
        
        // define component template
        let template =
        """
        <tr id="#(component.dummymodel1.id)">
            <td>#(component.dummymodel1.text)</td>
            <td>#(component.dummymodel2.text2)</td>
        </tr>
        """
        
        // get component data context
        guard let context = await MyComponent.makeContext(of: modelID, in: app.db) else { return XCTFail("Failed to create context") }
        
        // render template with context
        let html = try renderLeafForTesting(template, with: context)
        
        // validate rendering
        XCTAssertEqual(html,
        """
        <tr id="3D8965CD-C57D-49D2-A1F2-8EE8964DAF72">
            <td>Hello</td>
            <td>World</td>
        </tr>
        """,
        "HTML did not match expected output")
        
        // Optional: Print rendered HTML for inspection
        print("Rendered HTML:\n\(html)")
        
        try await app.asyncShutdown()
    }
}

#if DEBUG
func renderLeafForTesting<E: Encodable>(_ templateString: String, with context: E) throws -> String
{
    // 1. Convert Encodable context to LeafData
    let contextData = try JSONEncoder().encode(context)
    let dict = try JSONSerialization.jsonObject(with: contextData) as? [String: Any] ?? [:]
    let leafContext = convertDictionaryToLeafData(dict)
    
    // 2. Set up LeafKit components for direct rendering
    var lexer = LeafLexer(name: "inline-template", template: templateString)
    let tokens = try lexer.lex()
    
    var parser = LeafParser(name: "inline-template", tokens: tokens)
    let ast = try parser.parse()
    
    var serializer = LeafSerializer(ast: ast, ignoreUnfoundImports: false)
    
    // 3. Perform the serialization
    let buffer = try serializer.serialize(context: leafContext)
    
    // 4. Convert ByteBuffer to String
    return buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) ?? ""
}

// Recursively converts a dictionary with Any values to a dictionary with LeafData values
private func convertDictionaryToLeafData(_ dictionary: [String: Any]) -> [String: LeafData]
{
    var result = [String: LeafData]()
    
    for (key, value) in dictionary
    {
        result[key] = convertToLeafData(value)
    }
    
    return result
}

// Converts a single value to LeafData
private func convertToLeafData(_ value: Any) -> LeafData
{
    switch value
    {
        case let string as String: return .string(string)
        case let int as Int: return .int(int)
        case let double as Double: return .double(double)
        case let bool as Bool: return .bool(bool)
        case let array as [Any]: return .array(array.map { convertToLeafData($0) })
        case let dict as [String: Any]: return .dictionary(convertDictionaryToLeafData(dict))
        case let date as Date: return .double(date.timeIntervalSince1970)
        case let uuid as UUID: return .string(uuid.uuidString)
        case let data as Data: return .data(data)
        case is NSNull: return .nil(.string)
        default: return .nil(.string)
    }
}
#endif
