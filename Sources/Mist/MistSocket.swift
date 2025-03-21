import Vapor
import Fluent
import Leaf
import LeafKit

extension Mist
{
    static func registerMistSocket(using config: Mist.Configuration)
    {
        config.app.webSocket("mist", "ws")
        { request, ws async in
            
            // create new connection on upgrade
            let clientID = UUID()
            
            // add new connection to actor
            await Clients.shared.add(client: clientID, socket: ws)
            
            try? await ws.send("{ \"msg\": \"Server Welcome Message\" }")
            
            // receive client message
            ws.onText()
            { ws, text async in
                
                // abort if message is not of type Mist.Message
                guard let data = text.data(using: .utf8) else { return }
                guard let message = try? JSONDecoder().decode(Message.self, from: data) else { return }
                
                switch message
                {
                    case .subscribe(let component): do
                    {
                        if await Clients.shared.addSubscription(component, to: clientID)
                        {
                            try? await ws.send("{ \"msg\": \"Subscribed to \(component)\" }")
                        }
                        else
                        {
                            try? await ws.send("{ \"error\": \"Component '\(component)' not found\" }")
                        }
                    }
                        
                    case .unsubscribe(let component): do
                    {
                        await Clients.shared.removeSubscription(component, for: clientID)
                        
                        try? await ws.send("{ \"msg\": \"Unsubscribed to \(component)\" }")
                    }
                        
                        // server does not handle other message types
                    default: return
                }
            }
            
            // remove connection from actor on close
            ws.onClose.whenComplete() { _ in Task { await Clients.shared.remove(client: clientID) } }
        }
    }
}
