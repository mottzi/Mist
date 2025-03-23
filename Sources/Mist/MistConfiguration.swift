import Vapor
import Fluent

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
        public init(for app: Application, using components: [any Mist.Component.Type], db: DatabaseID? = nil)
        {
            self.app = app
            self.db = db
            self.components = components
        }
    }
}

