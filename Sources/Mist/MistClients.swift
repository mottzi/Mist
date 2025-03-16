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
    func addSubscription(_ component: String, for id: UUID)
    {
        // abort if client is not found
        guard let index = connections.firstIndex(where: { $0.id == id }) else { return }

        // add component to client's subscriptions
        connections[index].subscriptions.insert(component)
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
