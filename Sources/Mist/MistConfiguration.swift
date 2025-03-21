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
        
        let testing: Bool
        
        let components: [any Mist.Component.Type]
        
        // initialize with application
        public init(app: Application, components: [any Mist.Component.Type], db: DatabaseID? = nil, testing: Bool = false)
        {
            self.app = app
            self.db = db
            self.components = components
            self.testing = testing
        }
    }
}
