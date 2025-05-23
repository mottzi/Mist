import Vapor
import Fluent

// thread-safe component registry
actor Components
{
    static let shared = Components()
    private init() { }
    
    // mist component storage (type-erasure pattern)
    private var components: [AnyComponent] = []

    // type-safe mist component registration
    func register<C: Mist.Component>(component: C.Type, using config: Mist.Configuration)
    {
        // abort if default naming was overwritten
        // guard component.name == String(describing: C.self) else { assertionFailure("test"); return }
        
        // abort if component name is already registered
        guard components.contains(where: { $0.name == C.name }) == false else { return }
        
        // register database listeners for component models
        for model in component.models
        {
            // search for component using this model
            let isModelUsed = components.contains()
            {
                $0.models.contains { ObjectIdentifier($0) == ObjectIdentifier(model) }
            }
            
            // if this model is not yet used
            if isModelUsed == false
            {
                // register db model listener middleware
                model.createListener(using: config, on: config.db)
            }
        }
        
        // add new type erased mist component to storage
        if let testableComponent = component as? any TestableComponent.Type
        {
            // for test components
            components.append(AnyComponent(testableComponent))
        }
        else
        {
            // for regular components
            components.append(AnyComponent(component))
        }
    }
    
    // retrieve all components that use a specific model
    func getComponents<M: Model>(for type: M.Type) -> [AnyComponent]
    {
        return components.filter { $0.models.contains { ObjectIdentifier($0) == ObjectIdentifier(type) } }
    }
    
    // checks if component with given name exists
    func hasComponent(name: String) -> Bool
    {
        return components.contains { $0.name == name }
    }
}

extension Components
{
    // initialize component system
    func registerComponents(definedIn config: Mist.Configuration) async
    {
        // register configured components
        for component in config.components
        {
            await Components.shared.register(component: component, using: config)
        }
    }
}

#if DEBUG
extension Components
{
    func registerWOListenerForTesting<C: Mist.Component>(_ component: C.Type)
    {
        // abort if component name is already registered
        guard components.contains(where: { $0.name == C.name }) == false else { return }
        
        // add new type erased mist component to storage
        components.append(Mist.AnyComponent(component))
    }
    
    func getStorgeForTesting() async -> [Mist.AnyComponent]
    {
        return components
    }
    
    func resetForTesting() async
    {
        components = []
    }
}
#endif
