import Vapor
import Fluent

public struct Mist
{
    public static func configure(using config: Mist.Configuration) async
    {
        await Mist.registerComponents(using: config)
        Mist.registerMistSocket(using: config)
        config.app.copyMistJS()
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

extension Application
{
    public func copyMistJS()
    {
        // Destination path
        let destPath = self.directory.publicDirectory + "mist.js"
        
        // Abort if the file already exists
        guard !FileManager.default.fileExists(atPath: destPath) else { return }
        
        // Get the JS content directly as a string
        let jsContent = Self.getMistJsContent()
        
        do
        {
            try FileManager.default.createDirectory(at: URL(fileURLWithPath: self.directory.publicDirectory),
                                                    withIntermediateDirectories: true)
            
            try jsContent.write(to: URL(fileURLWithPath: destPath), atomically: true, encoding: .utf8)
            self.logger.notice("Successfully created mist.js in Public directory")
        }
        catch
        {
            self.logger.error("\(error.localizedDescription)")
        }
    }
    
    private static func getMistJsContent() -> String
    {
        """
        class MistSocket
        {
            constructor()
            {
                // websocket
                this.socket = null;
                
                // reconnect
                this.timer = null;
                this.initialDelay = 1000;
                this.interval = 5000;
                
                document.addEventListener('visibilitychange', () => this.visibilityChange());
                window.addEventListener('online', () => this.connect());
            }
            
            subscribeToPageComponents()
            {
                console.log("subscribing to server components...");
                
                // Collect unique component types using a Set
                const uniqueComponents = new Set();
                
                // Find all elements with mist-component attribute
                document.querySelectorAll('[mist-component]').forEach(element =>
                {
                    const component = element.getAttribute('mist-component');
                    
                    if (component)
                    {
                        uniqueComponents.add(component);
                    }
                });
                
                // Subscribe to each unique component type exactly once
                uniqueComponents.forEach(component =>
                {
                    this.subscribe(component);
                });
            }
            
            subscribe(component)
            {
                if (this.isConnected())
                {
                    const message =
                    {
                        type: 'subscribe',
                        component: component
                    };
                    
                    this.socket.send(JSON.stringify(message));
                }
            }
            
            unsubscribe(component)
            {
                if (this.isConnected())
                {
                    const message =
                    {
                        type: 'unsubscribe',
                        component: component
                    };
                    
                    this.socket.send(JSON.stringify(message));
                }
            }
            
            isConnected() { return this.socket?.readyState === WebSocket.OPEN; }
            isConnecting() { return this.socket?.readyState === WebSocket.CONNECTING; }
            
            connect()
            {
                // abort if already connected or currently connecting
                if (this.isConnected() || this.isConnecting()) return;
                
                // close existing socket
                if (this.socket) { this.socket.close(); this.socket = null; }
                
                // create new socket and try to connect
                this.socket = new WebSocket('wss://mottzi.de/mist/ws/');
                
                // connected: stop existing reconnect timer
                this.socket.onopen = () =>
                {
                    if (this.timer) { clearInterval(this.timer); this.timer = null; }
                    
                    // subscribe to components after ws connection is established
                    this.subscribeToPageComponents();
                };
                
                // parse incoming messages
                this.socket.onmessage = (event) =>
                {
                    try
                    {
                        console.log(`RAW: ${event.data}`);
                        const data = JSON.parse(event.data);
                        
                        if (data.type === 'componentUpdate')
                        {
                            const elements = document.querySelectorAll(`[mist-component="${data.component}"][mist-id="${data.id}"]`);
                            
                            elements.forEach(element =>
                            {
                                element.outerHTML = data.html;
                            });
                        }
                    }
                    catch (error)
                    {
                        console.error(`WS: Failed to parse message: ${error}`);
                    }
                };
                
                // disconnected: start reconnect timer
                this.socket.onclose = () =>
                {
                    // abort if a reconnect timer is already running
                    if (this.timer) return
                        
                        console.log("WS: ... closed -> Connect in 1s ...");
                    
                    // start trying every 5s
                    setTimeout(() =>
                    {
                        this.connect();
                        
                        this.timer = setInterval(() =>
                        {
                            this.connect();
                        },
                        this.interval);
                    },
                    this.initialDelay);
                };
            }
            
            visibilityChange()
            {
                if (document.visibilityState === "visible")
                {
                    console.log('visibilityState === "visible" -> calling connect()')
                    this.connect();
                }
            }
        }

        // Wait for the DOM to be fully loaded before executing the code
        document.addEventListener('DOMContentLoaded', function ()
        {
            window.ws = new MistSocket();
            window.ws.connect()
        });
        """
    }
}
