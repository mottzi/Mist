# Mist

Mist could be a lightweight Swift server-side rendering (SSR) extension for Vapor server applications that enables real-time UI component updates through WebSockets.

> [!WARNING]
> This is in a very alpha state and not at all production ready. If you know Swift, please contribute in any form at all. This is just a bare bones prototype implementation.

## Overview

This prototype is made up of 8 server side Swift files and 1 client side JavaScript file:
| File | Main Function |
|----------|----------|
| **mist**.js | client-side DOM updates |
| &nbsp; |  |
| **Mist**.swift | main entry point, configuration, initialization |
| **MistComponent**.swift | template context generation, html rendering |
| **MistModel**.swift | template context generation |
| **MistListener**.swift | database update detection, messaging |
| **MistClients**.swift | client registry, messaging  |
| **MistComponents**.swift | component registry |
| **MistSocket**.swift | web socket server, handles client component subscriptions |
| **MistMessage**.swift | type safe client-server-client communication over web sockets |

## Setup

### 1. Add package dependency:
```swift
// Package.swift
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

### 2. Define database table and model using Fluent:

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
> The current implementation of Mist only supports a one-to-one component model relationship in multi model components. Mist will implicitly use a model's ```id: UUID``` property  as identifier (```model1.id == model2.id```).

```swift
struct DummyComponent: Mist.Component
{
    static let models: [any Mist.Model.Type] = [
        DummyModel1.self,
        DummyModel2.self
    ]
}
```

### 4. Add component template (DummyComponent.leaf):

```html
<tr mist-component="DummyComponent"
    mist-id="#(component.dummymodel1.id)">
    <td>#(component.dummymodel1.id)</td>
    <td>#(component.dummymodel1.text)</td>
    <td>#(component.dummymodel2.text)</td>
</tr>

```

### 5. Add template for an initial page request (InitialDummies.leaf):

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

### 6. Add route for initial page request (routes.swift):
```swift
app.get("dummies")
{ request async throws -> View in
    // render initial page template with full data set
    let context = await DummyComponent.makeContext(ofAll: request.db)
    return try await request.view.render("InitialDummies", context)
}
```
