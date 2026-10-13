import XCTest
@testable import PlantChat

final class PlantChatIntentTests: XCTestCase {
    func test_init_isStatusForStatusWords() {
        [
            "What's your status?", "Show me your stats", "Any statistics?", "How are the conditions?",
            "Give me your data", "What are your readings?", "Tell me all the values"
        ].forEach { message in
            XCTAssertEqual(PlantChatIntent(message), .status, message)
        }
    }

    func test_init_isOtherForSensorsAlone() {
        [
            "How are your water and light?", "Is it hot? How humid is the air?", "Moisture, light and temperature?",
            "How is your light?", "Are you hot or cold?", "Do you need water?"
        ].forEach { message in
            XCTAssertEqual(PlantChatIntent(message), .other, message)
        }
    }

    func test_init_isOtherForBareAllAndSmallTalk() {
        ["Tell me all about you", "Are you all right?", "Hi there!", "All good?"].forEach { message in
            XCTAssertEqual(PlantChatIntent(message), .other, message)
        }
    }

    func test_init_isOtherWhenMessageSaysNotTo() {
        ["Don't give me your status", "Dont give me your stats", "Not the status please", "Do not tell me the readings"].forEach { message in
            XCTAssertEqual(PlantChatIntent(message), .other, message)
        }
    }
}
