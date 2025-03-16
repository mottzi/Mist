import Vapor
import Fluent

public struct Mist
{
    static func configure(using config: Mist.Configuration)
    {
        Mist.registerComponents(using: config)
        Mist.registerMistSocket(using: config)
    }
}

extension Mist
{
    // initialize component system
    static func registerComponents(using config: Configuration)
    {
        // register configured components
        Task
        {
            for component in config.components
            {
                await Components.shared.register(component: component, using: config)
            }
        }
    }
}
