import Vapor
import Fluent

extension Mist
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
extension Mist.Component
{
    // name matches component type name
    static var name: String { String(describing: self) }
    
    // template matches component type name
    static var template: String { String(describing: self) }
}
    
// default context
extension Mist.Component
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
    static func shouldUpdate<M: Model>(for model: M) -> Bool
    {
        return models.contains()
        { modelType in
            ObjectIdentifier(modelType) == ObjectIdentifier(M.self)
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
        private let _shouldUpdate: @Sendable (Any) -> Bool
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
                guard let model = model as? any Model else { return false }
                
                return C.shouldUpdate(for: model)
            }
            
            // capture concrete type function
            self._render =
            { id, db, renderer in
                await C.render(id: id, on: db, using: renderer)
            }
        }
        
        // forward call to the captured function
        func shouldUpdate(for model: Any) -> Bool
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
