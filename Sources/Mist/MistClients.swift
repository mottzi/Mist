import Vapor
import Fluent

extension Mist
{
    actor Clients
    {
        static let shared = Clients()
        
        private var clients: [Client] = []
        
        func getClients() -> [Client]
        {
            return clients
        }
        
        func getSubscribers(of component: String) -> [Client]
        {
            return clients.filter { $0.subscriptions.contains(component) }
        }
    }
}

// clients
extension Mist.Clients
{
    struct Client
    {
        let id: UUID
        let socket: WebSocket
        var subscriptions: Set<String> = []
    }
    
    // add connection to actor
    func add(client id: UUID, socket: WebSocket)
    {
        clients.append(Client(id: id, socket: socket))
    }
    
    // remove connection from actor
    func remove(client id: UUID)
    {
        clients.removeAll { $0.id == id }
    }
}
    
// subscriptions
extension Mist.Clients
{
    // add subscription to connection
    @discardableResult
    func addSubscription(_ component: String, to client: UUID) async -> Bool
    {
        // abort if component doesn't exist in registry
        guard await Mist.Components.shared.hasComponent(name: component) else { return false }
        
        // abort if client doesn't exist in registry
        guard let index = clients.firstIndex(where: { $0.id == client }) else { return false }
        
        // add component to client's subscriptions
        let result = clients[index].subscriptions.insert(component)
        
        // return true if added, false if already present
        return result.inserted
    }
}

// broadcasting
extension Mist.Clients
{
    // send model update message to all subscribed clients
    func broadcast(_ message: Mist.Message) async
    {
        // encode component update message
        guard case .update(let component, _, _, _) = message else { return }
        guard let jsonData = try? JSONEncoder().encode(message) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        // get subscribed clients of component
        let subscribers = getSubscribers(of: component)
        
        // send update message payload
        for subscriber in subscribers { Task { try? await subscriber.socket.send(jsonString) } }
    }
}

#if DEBUG
extension Mist.Clients
{
    func resetForTesting() async
    {
        clients = []
    }
}
#endif
