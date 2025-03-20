@preconcurrency import Vapor
import Fluent

extension Mist.Model
{
    // registers db middleware listener on Fluent db changes
    static func createListener(using config: Mist.Configuration, on db: DatabaseID?)
    {
        config.app.databases.middleware.use(Mist.Listener<Self>(config: config), on: db)
    }
}

extension Mist
{
    // generic database model update listener
    struct Listener<M: Mist.Model>: AsyncModelMiddleware
    {
        let config: Mist.Configuration
        let logger = Logger(label: "[Mist]")
        
        // update callback
        func update(model: M, on db: Database, next: AnyAsyncModelResponder) async throws
        {
            logger.warning("Listener for model '\(String(describing: model.self))' was triggered.")
            
            // perform middleware chain
            try await next.update(model, on: db)
            
            // Ensure we have a UUID
            guard let modelID = model.id else { return }
            
            // get type-safe components registered for this model type
            let components = await Components.shared.getComponents(for: M.self)
            
            // process each component
            for component in components
            {
                await renderComponent(component, for: model, modelID: modelID, db: db, renderer: config.app.leaf.renderer)
            }
        }
        
        // Process a single component and broadcast update if needed
        private func renderComponent(_ component: AnyComponent, for model: M, modelID: UUID, db: Database, renderer: ViewRenderer) async
        {
            // Only update if component says it should
            guard component.shouldUpdate(for: model) else { return }
            
            // render using ID and database
            guard let html = await component.render(id: modelID, on: db, using: renderer) else { return }
            
            // create update message with component data
            let message = Message.componentUpdate(
                component: component.name,
                action: "update",
                id: modelID,
                html: html
            )
            
            // broadcast to all connected clients
            await Clients.shared.broadcast(message)
            
            logger.warning("Broadcasting Component '\(component.name)'")
        }
    }
}
