import PlantShared
import XCTest
@testable import PlantChat

@MainActor
final class PlantChatReplyGuardTests: PlantChatXCTestCase {
    // MARK: - clean

    func test_clean_keepsTextOfBoldAndRemovesHeadingsAndListMarkers() {
        let text = "## Hello there!\n**I'm fine.**\n- Soil is good.\n* Light is good.\n2. Air is good."

        XCTAssertEqual(PlantChatReplyGuard.clean(text), "Hello there! I'm fine. Soil is good.")
    }

    func test_clean_collapsesLineBreaksIntoSpaces() {
        XCTAssertEqual(PlantChatReplyGuard.clean("I'm\nfeeling\n\ngreat today"), "I'm feeling great today")
    }

    func test_clean_keepsTextOfItalicWordInsideASentence() {
        XCTAssertEqual(PlantChatReplyGuard.clean("I *really* need water."), "I really need water.")
    }

    func test_clean_stillRemovesStageDirections() {
        XCTAssertEqual(PlantChatReplyGuard.clean("*sighs* I'm fine. (smiles)"), "I'm fine.")
        XCTAssertEqual(PlantChatReplyGuard.clean("I'm fine *smiles*"), "I'm fine")
    }

    // MARK: - firstSentence

    func test_firstSentence_deliversOnlyTheFirstSentence() {
        XCTAssertEqual(PlantChatReplyGuard.firstSentence(of: "I feel great! Moisture is 50%. Bye."), "I feel great!")
        XCTAssertEqual(PlantChatReplyGuard.firstSentence(of: ""), "")
    }

    // MARK: - contradicts

    func test_contradicts_whenHappyOrDrowningReplySaysThirsty() {
        ["I'm so thirsty!", "I need water.", "My soil is dry.", "I could need a drink"].forEach { reply in
            XCTAssertTrue(PlantChatReplyGuard.contradicts(reply, mood: .happy), reply)
            XCTAssertTrue(PlantChatReplyGuard.contradicts(reply, mood: .drowning), reply)
        }
    }

    func test_contradicts_notWhenHappyReplySaysItIsNotThirsty() {
        ["I'm not thirsty at all!", "I don’t need water, thanks.", "I love the sun."].forEach { reply in
            XCTAssertFalse(PlantChatReplyGuard.contradicts(reply, mood: .happy), reply)
        }
    }

    func test_contradicts_whenThirstyReplySaysNoWaterNeeded() {
        ["I don't need water.", "I'm not thirsty.", "I do not need water right now."].forEach { reply in
            XCTAssertTrue(PlantChatReplyGuard.contradicts(reply, mood: .thirsty), reply)
            XCTAssertTrue(PlantChatReplyGuard.contradicts(reply, mood: .veryThirsty), reply)
        }
        XCTAssertFalse(PlantChatReplyGuard.contradicts("I need water, please.", mood: .thirsty))
    }

    func test_contradicts_neverForOtherMoods() {
        [PlantMood.tooDark, .tooHot, .tooCold, .dryAir, .offline].forEach { mood in
            XCTAssertFalse(PlantChatReplyGuard.contradicts("I'm thirsty and I don't need water.", mood: mood), "\(mood)")
        }
    }

    // MARK: - greetingFits

    func test_greetingFits_whenProblemMoodMentionsItsNeed() {
        let cases: [(PlantMood, String)] = [
            (.thirsty, "Hi! Some water, please?"),
            (.veryThirsty, "Hello, I'm parched!"),
            (.drowning, "Hi, I'm a bit soggy."),
            (.tooDark, "Hey, could I get more light?"),
            (.tooHot, "Hi, it's warm in here."),
            (.tooCold, "Hello, I'm chilly!"),
            (.dryAir, "Hi, the air is so dry."),
            (.offline, "Hi, I can't feel my sensor.")
        ]

        cases.forEach { mood, line in XCTAssertTrue(PlantChatReplyGuard.greetingFits(line, mood: mood), "\(mood)") }
    }

    func test_greetingFits_notWhenProblemMoodLeavesOutItsNeed() {
        [PlantMood.thirsty, .veryThirsty, .drowning, .tooDark, .tooHot, .tooCold, .dryAir, .offline].forEach { mood in
            XCTAssertFalse(PlantChatReplyGuard.greetingFits("Good afternoon, friend!", mood: mood), "\(mood)")
        }
    }

    func test_greetingFits_notWhenGreetingContradictsTheMood() {
        XCTAssertFalse(PlantChatReplyGuard.greetingFits("Hi! I'm so thirsty.", mood: .happy))
        XCTAssertFalse(PlantChatReplyGuard.greetingFits("Hi! I don't need water.", mood: .thirsty))
    }

    func test_greetingFits_anyKindGreetingWhenHappy() {
        XCTAssertTrue(PlantChatReplyGuard.greetingFits("Hello, friend!", mood: .happy))
    }

    func test_greetingFits_forEveryMoodTemplate() {
        PlantMood.allCases.forEach { mood in
            let template = PlantChatTemplate.speech(mood: mood, isSleeping: false)

            XCTAssertTrue(PlantChatReplyGuard.greetingFits(template, mood: mood), "\(mood)")
        }
    }

    // MARK: - confusesRoles

    func test_confusesRoles_whenPlantOffersToLookAfterThePerson() {
        ["I'll water you soon!", "Don't worry, I will feed you.", "Let me help you.", "I’ll water you."].forEach { reply in
            XCTAssertTrue(PlantChatReplyGuard.confusesRoles(reply), reply)
        }
    }

    func test_confusesRoles_whenReplyOpensByEchoingThePerson() {
        ["You're asking me about water?", "You did ask nicely.", "You said hello!"].forEach { reply in
            XCTAssertTrue(PlantChatReplyGuard.confusesRoles(reply), reply)
        }
    }

    func test_confusesRoles_notForThePlantsOwnRole() {
        ["Thank you for watering me!", "Could you water me?", "I love it when you said hello earlier."].forEach { reply in
            XCTAssertFalse(PlantChatReplyGuard.confusesRoles(reply), reply)
        }
    }

    // MARK: - repeats

    func test_repeats_ignoresCasePunctuationAndNumbers() {
        XCTAssertTrue(PlantChatReplyGuard.repeats("I'm at 24%!", anyOf: ["im at 31"]))
        XCTAssertTrue(PlantChatReplyGuard.repeats("It's 20.7 °C here.", anyOf: ["Other", "it's 21.0 °C here"]))
    }

    func test_repeats_whenFirstSixWordsMatch() {
        XCTAssertTrue(PlantChatReplyGuard.repeats(
            "I could really use a drink, my friend!",
            anyOf: ["I could really use a drink right now."]
        ))
    }

    func test_repeats_notForShortRepliesThatOnlyShareTheirStart() {
        XCTAssertFalse(PlantChatReplyGuard.repeats("I'm fine, thanks.", anyOf: ["I'm fine and happy."]))
        XCTAssertFalse(PlantChatReplyGuard.repeats("I could really use some sun today.", anyOf: ["I could really use a drink right now."]))
    }
}
