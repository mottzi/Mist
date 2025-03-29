# Mist

Mist is a lightweight Swift server components extension for Vapor applications. It enables real-time UI component updates through type safe web socket communication.

> [!WARNING]
> This is just a proof of concept implementation and not at all production ready!

If you know any Swift at all, please contribute to this project however you can! Together we can make this Swift's [LiveView](https://hexdocs.pm/phoenix_live_view/welcome.html) / [Livewire](https://livewire.laravel.com)!

## Overview

This prototype is made up of 8 .swift and 1 .js file:

```swift
// mist.js:                 client-side DOM updates

// Mist.swift:              main entry point, configuration, initialization
// MistComponent.swift:     template context generation, html rendering
// MistModel.swift:         template context generation
// MistListener.swift:      database update detection, messaging
// MistClients.swift:       client registry, messaging
// MistComponents.swift:    component registry
// MistSocket.swift:        web socket server, handles client component subscriptions
// MistMessage.swift:       type safe client-server-client communication over web sockets
```

## Setup

### 1. Add package dependency (Package.swift):
```swift
let package = Package(
	...
    dependencies: [
        .package(url: "https://github.com/mottzi/Mist", from: "0.5.0"),
    ],
    targets: [
        .executableTarget(
            ...
            dependencies: [
                .product(name: "Mist", package: "Mist"),
                ...
            ]
        )
    ]
)
```
Mist has Vapor, Fluent and Leaf declared as internal dependencies.

### 2. Define database table and model:

```swift
import Vapor
import Fluent
import Mist

final class DummyModel1: Mist.Model, Content
{
    static let schema = "dummymodels"
    
    @ID(key: .id) var id: UUID?
    @Field(key: "text") var text: String
    @Timestamp(key: "created", on: .create) var created: Date?
    
    init() {}
    init(text: String) { self.text = text }
}

extension DummyModel1
{
    struct Table: AsyncMigration
    {
        func prepare(on database: Database) async throws
        {
            try await database.schema(DummyModel1.schema)
                .id()
                .field("text", .string, .required)
                .field("created", .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws
        {
            try await database.schema(DummyModel1.schema).delete()
        }
    }
}
```
Do the same with DummyModel2...

### 3. Define a server component:

> [!WARNING]
> The current implementation only supports one-to-one component model relationships in multi model components. Mist will implicitly use a model's ```id: UUID``` property  as identifier (```model1.id == model2.id```).

```swift
import Mist

struct DummyComponent: Mist.Component
{
    static let models: [any Mist.Model.Type] = [
        DummyModel1.self,
        DummyModel2.self
    ]
}
```

### 4. Add component template: 

File *Resources/Views/DummyComponent.leaf*:

```html
<tr mist-component="DummyComponent"
    mist-id="#(component.dummymodel1.id)">
    <td>#(component.dummymodel1.id)</td>
    <td>#(component.dummymodel1.text)</td>
    <td>#(component.dummymodel2.text)</td>
</tr>

```

### 5. Add template for an initial page request:

File *Resources/Views/InitialDummies.leaf*:

```html
<!DOCTYPE html>
<html>
<body>
    <table>
        <thead>
            <tr>
                <th>ID</th>
                <th>DummyModel1</th>
                <th>DummyModel2</th>
            </tr>
        </thead>
        <tbody>
        #for(component in components):
            #extend("DummyComponent")
        #endfor
        </tbody>
    </table>

    <script src="/mist.js"></script>
</body>
</html>
```

### 6. Add route for initial page request:

File *Sources/App/routes.swift*:

```swift
...
app.get("dummies")
{ request async throws -> View in
    // render initial page template with full data set
    let context = await DummyComponent.makeContext(ofAll: request.db)
    return try await request.view.render("InitialDummies", context)
}
...
```

### 7. Configure Mist

File *Sources/App/configure.swift*:

```swift
...
let config = Mist.Configuration(for: app, using: [
    DummyRow.self, DummyRowCustom.self
])

await Mist.configure(using: config)
...
```

## Data Flow Charts

To help the community understand the current implementation of Mist, here are some flow charts that help visualize the flow of data through Mist:

<details>
<summary>1. Initial Page Request</summary>
	
![Initial](https://mottzi.de/space/mist0.svg?)

1. Client requests initial full page
2. Server fetches necessary data from database
3. Server creates template context
4. Server renders full page
5. Server sends initial HTML (including mist.js) to client

</details>

<details>
<summary>2. Component Subscription</summary>
	
![Initial](https://mottzi.de/space/mist-sub1.svg?)

1. Client uses mist.js to connect to server through web socket
2. Server adds the connected client to registry
3. Client scans DOM for "mist-component" HTML attribute
4. Client sends subscription messages of found components
5. Server adds subscriptions to client inside of registry

</details>

<details>
<summary>3. Component Update Broadcasting</summary>
	
![Initial](https://mottzi.de/space/mist-listener.svg?)

1. Server registers middleware listeners for each model
2. Database model entry changes
3. Mist.Listener for that model triggers
4. Server identifies components using changed model
5. Server re-renders affected components and creates update messages
6. Server identifies clients that are subscribed to these components
7. Server broadcasts update messages to subscribed clients

</details>
