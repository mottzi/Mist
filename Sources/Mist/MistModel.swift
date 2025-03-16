import Vapor
import Fluent

extension Mist
{
    // mist models are fluent models that use UUID as id
    protocol Model: Fluent.Model where IDValue == UUID {}
}

// type-erased finder operations
extension Mist.Model
{
    // type-erased find() function as closure that captures concrete model type
    static var find: (UUID, Database) async -> (any Mist.Model)?
    {
        let closure = { id, db in
            // Use Self to refer to the concrete model type
            return try? await Self.find(id, on: db)
        }
        
        return closure
    }
    
    // type-erased findAll() function as closure that captures concrete model type
    static var findAll: (Database) async -> [any Mist.Model]?
    {
        let closure = { db in
            // Use Self to refer to the concrete model type
            return try? await Self.query(on: db).all()
        }
        
        return closure
    }
}

extension Mist
{
    // container to hold model instances for rendering
    struct ModelContainer: Encodable
    {
        // store encodable model data keyed by lowercase model type name
        private var models: [String: Encodable] = [:]
        
        // Add a model instance to the container
        mutating func add<M: Mist.Model>(_ model: M, for key: String)
        {
            models[key] = model
        }
        
        // flattens the models dictionary when encoding making properties directly accessible in template
        func encode(to encoder: Encoder) throws
        {
            var container = encoder.container(keyedBy: StringCodingKey.self)
            
            for (key, value) in models
            {
                try container.encode(value, forKey: StringCodingKey(key))
            }
        }
        
        var isEmpty: Bool { return models.isEmpty }
    }
    
    // helper struct for string-based coding keys
    struct StringCodingKey: CodingKey
    {
        var stringValue: String
        var intValue: Int?
        
        init(_ string: String)
        {
            self.stringValue = string
            self.intValue = nil
        }
        
        init?(stringValue: String)
        {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int)
        {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }
    
    // single context
    struct SingleComponentContext: Encodable
    {
        let component: ModelContainer
    }
    
    // collection context
    struct MultipleComponentContext: Encodable
    {
        let components: [ModelContainer]
    }
}
