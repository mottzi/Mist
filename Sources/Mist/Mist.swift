import Vapor
import Fluent

public struct Mist
{
    public static func configure(using config: Mist.Configuration) async
    {
        // registers components in config with MistComponents
        await Mist.registerComponents(using: config)
        
        // registers subscription socket on server app
        Mist.registerMistSocket(on: config.app)
    }
}

extension Mist
{
    // initialize component system
    static func registerComponents(using config: Mist.Configuration) async
    {
        // register configured components
        for component in config.components
        {
            await Components.shared.register(component: component, using: config)
        }
    }
}
