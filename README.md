
# Mist

A lightweight server-side rendering (SSR) framework for Vapor applications that enables real-time UI updates through WebSockets.

This is in a very alpha state and not at all production ready, so feel free to make contributions to the source code!

## Setup

### Package dependency
 
 Add Mist as a package dependency in your Package.swift manifest file:

```swift
let package = Package(
	...
    dependencies: [
        // Mist has Vapor, Fluent and Leaf as dependency
        .package(url: "https://github.com/mottzi/Mist", from: "0.5.0"),
    ],
    targets: [
        .executableTarget(
            ...
            dependencies: [
                .product(name: "Mist", package: "Mist"),
                ...
            ]
        ),
    ]
)
```

### Database table and model

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

### Server component

```swift
struct DummyComponent: Mist.Component
{
    static let models: [any Mist.Model.Type] = [
        DummyModel1.self
    ]
}
```

### Template File (DummyComponent.leaf)

```html
<div mist-component="TestComponent" 
     mist-id="#(component.dummymodel1.id)">
    <span>#(component.dummymodel1.id)</span>
    <span>#(component.dummymodel1.text)</span>
</div>
```
