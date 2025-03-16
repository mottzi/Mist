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
        
        let components: [any Mist.Component.Type]
        
        // initialize with application
        init(app: Application, components: [any Mist.Component.Type], db: DatabaseID? = nil)
        {
            self.app = app
            self.db = db
            self.components = components
        }
    }
}
