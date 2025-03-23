import Vapor
import Fluent

public struct Mist
{
    public static func configure(using config: Mist.Configuration) async
    {
        await Mist.registerComponents(using: config)
        Mist.registerMistSocket(using: config)
    }
}

public extension Mist
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
