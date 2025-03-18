import XCTest
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import Mist

final class ComponentRendering: XCTestCase
{
    override func setUp() async throws
    {
        // reset singletons before each test
        await Mist.Clients.shared.resetForTesting()
        await Mist.Components.shared.resetForTesting()
    }
    
    // tests integrity of internal component registry and deduplication
    func testInternalStorage() async throws
    {
        
    }
}
