import Vapor
import Fluent

public struct Mist
{
    public static func configure(using config: Mist.Configuration) async
    {
        // registers components in config with MistComponents
        await Mist.registerComponents(definedIn: config)
        
        // registers subscription socket on server app
        Mist.registerMistSocket(on: config.app)
    }
}

public extension Mist
{
    struct Configuration: Sendable
    {
        // database configuration
        let db: DatabaseID?
        
        // reference to application
        let app: Application
        
        // configured components
        let components: [any Mist.Component.Type]
        
        // public initializer
        public init(for app: Application,
                    using components: [any Mist.Component.Type],
                    on db: DatabaseID? = nil)
        {
            self.app = app
            self.db = db
            self.components = components
        }
    }
}

extension Mist
{
    // initialize component system
    static func registerComponents(definedIn config: Mist.Configuration) async
    {
        // register configured components
        for component in config.components
        {
            await Components.shared.register(component: component, using: config)
        }
    }
}
