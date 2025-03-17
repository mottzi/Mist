import Vapor
import Fluent

extension Mist
{
    // thread-safe component registry
    actor Components
    {
        static let shared = Components()
        private init() { }
        
        // type-erased mist component storage
        private var components: [AnyComponent] = []

        // type-safe mist component registration
        func register<C: Component>(component: C.Type, using config: Mist.Configuration)
        {
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
                    model.createListener(using: config)
                }
            }
            
            // add new type erased mist component to storage
            components.append(AnyComponent(component))
        }
        
        // retrieve all components that use a specific model
        func getComponents<M: Model>(for type: M.Type) -> [AnyComponent]
        {
            return components.filter { $0.models.contains { ObjectIdentifier($0) == ObjectIdentifier(type) } }
        }
    }
}

#if DEBUG
extension Mist.Components
{
    func testGetComponentsArray() async -> [Mist.AnyComponent]
    {
        return components
    }
}
#endif
