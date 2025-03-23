import Vapor
import Fluent
@testable import LeafKit

// public component protocol
public extension Mist
{
    // mist component protocol
    protocol Component
    {
        // component name
        static var name: String { get }
        
        // component template
        static var template: String { get }
        
        // component models (joined by common id)
        static var models: [any Mist.Model.Type] { get }
    }
}

// default naming
public extension Mist.Component
{
    // name matches component type name
    static var name: String { String(describing: self) }
    
    // template matches component type name
    static var template: String { String(describing: self) }
}
    
// default context
public extension Mist.Component
{
    // create single component context
    static func makeContext(of componentID: UUID, in db: Database) async -> Mist.SingleComponentContext?
    {
        // data container for dynamic multi model context creation
        var componentData = Mist.ModelContainer()
        
        // fetch data of all component model types
        for modelType in models
        {
            // fetch model data by common component UUID using type erased model closure
            guard let modelData = await modelType.find(componentID, db) else { continue }
            
            // use model type name as template reference
            let modelName = String(describing: modelType).lowercased()
            
            // add model data to model container
            componentData.add(modelData, for: modelName)
        }
        
        // abort if no model data was added to model container
        guard componentData.isEmpty == false else { return nil }
        
        // return context with collected model data
        return Mist.SingleComponentContext(component: componentData)
    }
    
    // create collection context for multiple components
    static func makeContext(ofAll db: Database) async -> Mist.MultipleComponentContext?
    {
        // array of data containes for dynamic multi model context creation
        var componentDataCollection: [Mist.ModelContainer] = []
        
        // abort if not one model type was provided
        guard let primaryModelType = models.first else { return nil }
        
        // get data for all entries of the primary model
        guard let primaryModelEntries = await primaryModelType.findAll(db) else { return nil }
        
        // fetch data of related secondary models
        for primaryModelEntry in primaryModelEntries
        {
            // validate model UUID
            guard let componentID = primaryModelEntry.id else { continue }
            
            // fetch all related secondary model entries with matching id
            guard let componentContext = await makeContext(of: componentID, in: db) else { continue }
            
            // data of all models of component to data collection
            componentDataCollection.append(componentContext.component)
        }
        
        // abort if not one component loaded its model data in full
        guard componentDataCollection.isEmpty == false else { return nil }
        
        // return context of all components and their collected model data
        return Mist.MultipleComponentContext(components: componentDataCollection)
    }
}

// rendering
public extension Mist.Component
{
    // render component using dynamically generated template context
    static func render(id: UUID, on db: Database, using renderer: ViewRenderer) async -> String?
    {
        // create dynamic template datan context
        guard let context = await makeContext(of: id, in: db) else { return nil }
        
        // render the template using the context
        guard let buffer = try? await renderer.render(template, context).data else { return nil }

        // return html string
        return String(buffer: buffer)
    }
    
    // check if component should update when the provided model changes
    static func shouldUpdate<M: Mist.Model>(for model: M) -> Bool
    {
        return models.contains
        { componentModelType in
            ObjectIdentifier(componentModelType) == ObjectIdentifier(M.self)
        }
    }
}

extension Mist
{
    // type-erased component for storage in collections
    struct AnyComponent: Sendable
    {
        // component metadata
        let name: String
        let template: String
        let models: [any Model.Type]
        
        // type-erased functions
        private let _shouldUpdate: @Sendable (any Mist.Model) -> Bool
        private let _render: @Sendable (UUID, Database, ViewRenderer) async -> String?
        
        // create type-erased component from any concrete component type
        init<C: Component>(_ component: C.Type)
        {
            self.name = C.name
            self.template = C.template
            self.models = C.models
            
            // capture concrete type function
            self._shouldUpdate =
            { model in
                return C.shouldUpdate(for: model)
            }
            
            // capture concrete type function
            self._render =
            { id, db, renderer in
                print("*** Server rendering '\(C.name)' (file template)... ")
                return await C.render(id: id, on: db, using: renderer)
            }
        }
        
        // forward call to the captured function
        func shouldUpdate(for model: any Mist.Model) -> Bool
        {
            _shouldUpdate(model)
        }
        
        // forward call to the captured function
        func render(id: UUID, on db: Database, using renderer: ViewRenderer) async -> String?
        {
            await _render(id, db, renderer)
        }
    }
}

#if DEBUG
extension Mist
{
    protocol TestableComponent: Mist.Component
    {
        static func templateStringLiteral(id: UUID) -> String
    }
}

extension Mist.AnyComponent
{
    // create type-erased component from any concrete component type
    init<C: Mist.TestableComponent>(_ component: C.Type)
    {
        self.name = C.name
        self.template = C.template
        self.models = C.models
        
        // capture concrete type function
        self._shouldUpdate =
        { model in
            return C.shouldUpdate(for: model)
        }
        
        // capture concrete type function
        self._render =
        { id, db, renderer in
            print("*** Server rendering '\(C.name)' (string literal template)... ")
            
            // create dynamic template data context
            guard let context = await C.makeContext(of: id, in: db) else { return nil }
            
            // render testable component using its in-memory template string literal
            guard let html = try? renderLeafForTesting(C.templateStringLiteral(id: id), with: context) else { return nil }
            
            return html
        }
    }
}

private func renderLeafForTesting<E: Encodable>(_ templateString: String, with context: E) throws -> String
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
