import Vapor
import Fluent

extension Mist
{
    actor Clients
    {
        static let shared = Clients()
        
        internal var connections:
        [(
            id: UUID,
            socket: WebSocket,
            subscriptions: Set<String>
        )] = []
    }
}

// connections
extension Mist.Clients
{
    // add connection to actor
    func add(connection id: UUID, socket: WebSocket, subscriptions: Set<String> = [])
    {
        connections.append((id: id, socket: socket, subscriptions: subscriptions))
    }
    
    // remove connection from actor
    func remove(connection id: UUID)
    {
        connections.removeAll { $0.id == id }
    }
}
    
// subscriptions
extension Mist.Clients
{
    // add subscription to connection
    func addSubscription(_ componentName: String, to clientID: UUID) async -> Bool
    {
        // abort if client doesn't exist in registry
        guard let index = connections.firstIndex(where: { $0.id == clientID }) else { return false }
        
        // abort if component doesn't exist in registry
        guard await Mist.Components.shared.hasComponent(name: componentName) else { return false }
        
        // add component to client's subscriptions
        connections[index].subscriptions.insert(componentName)
        
        return true
    }
    
    // remove subscription from connection
    func removeSubscription(_ component: String, for id: UUID)
    {
        // abort if client is not found
        guard let index = connections.firstIndex(where: { $0.id == id }) else { return }
        
        // remove component from client's subscriptions
        connections[index].subscriptions.remove(component)
    }
}

// broadcasting
extension Mist.Clients
{
    // send model update message to all subscribed clients
    func broadcast(_ message: Mist.Message) async
    {
        guard let jsonData = try? JSONEncoder().encode(message) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        switch message
        {
            // update messages go to subscribers
            case .componentUpdate(let component, _, _, _): do
            {
                // get clients that are subscribed to env
                let subscribers = connections.filter { $0.subscriptions.contains(component) }
                
                // send them the update message
                for subscriber in subscribers { Task { try? await subscriber.socket.send(jsonString) } }
            }
        
            // server cant send other mist messages
            default: return
        }
    }
}

#if DEBUG
extension Mist.Clients
{
    func resetForTesting() async
    {
        connections = []
    }
}
#endif
