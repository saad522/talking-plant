import XCTest
@testable import PlantChat

final class PlantSpeechTextTests: XCTestCase {
    func test_clean_leavesPlainTextUnchanged() {
        XCTAssertEqual(PlantSpeechText.clean("I'm a little thirsty, 24 percent."), "I'm a little thirsty, 24 percent.")
    }

    func test_clean_removesAsterisksUnderscoresAndHashes() {
        XCTAssertEqual(PlantSpeechText.clean("*sighs* I need _water_ #now"), "sighs I need water now")
    }

    func test_clean_removesEmoji() {
        XCTAssertEqual(PlantSpeechText.clean("Thank you 🌱 so much 💧"), "Thank you so much")
    }

    func test_clean_removesEmojiSequences() {
        XCTAssertEqual(PlantSpeechText.clean("Hi 👨‍👩‍👧 there ❤️"), "Hi there")
    }

    func test_clean_keepsDigits() {
        XCTAssertEqual(PlantSpeechText.clean("It is 23 degrees"), "It is 23 degrees")
    }

    func test_clean_collapsesWhitespaceAndTrims() {
        XCTAssertEqual(PlantSpeechText.clean("  Hello \n\n  there\t friend  "), "Hello there friend")
    }

    func test_clean_deliversEmptyForEmojiOnlyReply() {
        XCTAssertEqual(PlantSpeechText.clean("🌱💧 *  * "), "")
    }
}
