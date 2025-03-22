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
        let text = #"{ "type": "subscribe", "component": "TestComponent2" }"#
        
        // try to decode json message to mist subscribe message
        guard let data = text.data(using: .utf8) else { return XCTFail("Failed to convert JSON string to data") }
        guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return XCTFail("Failed to decode data to Mist message") }
        guard case .subscribe(let component) = message else { return XCTFail("Valid but non-subscribe message") }

        XCTAssertEqual(component, "TestComponent2", "Mist message component should match JSON component string")
    }
    
    // tests encoding Mist.Message.subscribe to json
    func testSubscriptionEncoding() async
    {
        // Create a subscription message
        let subscriptionMessage = Mist.Message.subscribe(component: "TestComponent2")
        
        // Encode the message to JSON
        guard let jsonData = try? JSONEncoder().encode(subscriptionMessage) else { return XCTFail("Failed to encode subscription message") }
        
        // Decode JSON data to a dictionary for inspection
        guard let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return XCTFail("Failed to convert json to dictionary") }
        
        // Verify JSON structure and values
        XCTAssertEqual(dict["type"] as? String, "subscribe", "Type should be 'subscribe'")
        XCTAssertEqual(dict["component"] as? String, "TestComponent2", "Component should match")
        XCTAssertEqual(dict.count, 2, "JSON should only have 2 keys")
    }
    
    // tests decoding json componentUpdate message to Mist.Message type
    func testComponentUpdateDecoding() async
    {
        // Create a UUID to test with
        let testUUID = UUID()
        
        // Create JSON string for a componentUpdate message
        let text =
        """
        {
            "type": "componentUpdate",
            "component": "TestComponent",
            "action": "update",
            "id": "\(testUUID)",
            "html": "<div>Updated content</div>"
        }
        """
        
        // Try to decode json message to mist componentUpdate message
        guard let data = text.data(using: .utf8) else { return XCTFail("Failed to convert JSON string to data") }
        guard let message = try? JSONDecoder().decode(Mist.Message.self, from: data) else { return XCTFail("Failed to decode data to Mist message") }
        
        // Verify the message is of correct type
        guard case .componentUpdate(let component, let action, let id, let html) = message else { return XCTFail("Valid but non-componentUpdate message") }
        
        // Verify all fields match expected values
        XCTAssertEqual(component, "TestComponent", "Component name should match expected value")
        XCTAssertEqual(action, "update", "Action should match expected value")
        XCTAssertEqual(id, testUUID, "UUID should match expected value")
        XCTAssertEqual(html, "<div>Updated content</div>", "HTML content should match expected value")
    }
    
    // tests encoding Mist.Message.componentUpdate to json
    func testComponentUpdateEncoding() async
    {
        // Create a UUID to test with
        let testUUID = UUID()
        
        // Create a componentUpdate message
        let updateMessage = Mist.Message.componentUpdate(
            component: "TestComponent",
            action: "update",
            id: testUUID,
            html: "<div>Updated content</div>"
        )
        
        // Encode the message to JSON
        guard let jsonData = try? JSONEncoder().encode(updateMessage) else { return XCTFail("Failed to encode componentUpdate message") }
        
        // Decode JSON data to a dictionary for inspection
        guard let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return XCTFail("Failed to convert json to dictionary") }
        
        // Verify JSON structure and values
        XCTAssertEqual(dict["type"] as? String, "componentUpdate", "Type should be 'componentUpdate'")
        XCTAssertEqual(dict["component"] as? String, "TestComponent", "Component should match")
        XCTAssertEqual(dict["action"] as? String, "update", "Action should match")
        XCTAssertEqual(dict["id"] as? String, testUUID.uuidString, "UUID should match")
        XCTAssertEqual(dict["html"] as? String, "<div>Updated content</div>", "HTML should match")
        XCTAssertEqual(dict.count, 5, "JSON should have 5 keys")
    }
}
