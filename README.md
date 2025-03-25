

# Mist

Mist could be a lightweight Swift server-side rendering (SSR) extension for Vapor server applications that enables real-time UI component updates through WebSockets.

> [!WARNING]
> This is in a very alpha state and not at all production ready. If you know Swift, please contribute in any form at all. This is just a bare bones prototype implementation.

## Overview

## Setup

### Add package dependency:
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

### Define database table and model using Fluent:

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
### Define a server component:

> [!WARNING]
> The current implementation of Mist only supports a one-to-one component model relationship, implicitly using ```id: UUID```  as identifier (```model1.id == model1.id```).

```swift
struct DummyComponent: Mist.Component
{
    static let models: [any Mist.Model.Type] = [
        DummyModel1.self,
        DummyModel2.self
    ]
}
```

### Template File (DummyComponent.leaf)

```html
<div mist-component="TestComponent" 
     mist-id="#(component.dummymodel1.id)">
    <span>#(component.dummymodel1.id)</span>
    <span>#(component.dummymodel1.text)</span>
    <span>#(component.dummymodel2.text)</span>
</div>
```
