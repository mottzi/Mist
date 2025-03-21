import XCTest
import Vapor
import Fluent
import FluentSQLiteDriver
@testable import Mist

final class MistMessageTests: XCTestCase
{
    override func setUp() async throws
    {
        // reset singletons before each test
        await Mist.Clients.shared.resetForTesting()
        await Mist.Components.shared.resetForTesting()
    }
    
    // tests decoding json subscription message to Mist.Message type
    func testSubscriptionDecoding() async
    {
        // create test json message
        let text = #"{ "type": "subscribe", "component": "TestComponent2" }"#
        
        // try to decode json message to mist message
        guard let data = text.data(using: .utf8) else { return XCTFail("Failed to convert JSON string to data") }
        guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return XCTFail("Failed to decode data to Mist message") }
        
        switch message
        {
            // ensure correct decoding
            case .subscribe(let component): do
            {
                // test correct decoding of component name
                XCTAssertEqual(component, "TestComponent2", "Mist message component should match JSON component string")
            }
                
            // ensure correct decoding
            default: return XCTFail("Valid but non-subscribe message")
        }
    }
}
