import PlantChat
import PlantShared
import XCTest

@MainActor
final class PlantChatUIITests: PlantChatiOSXCTestCase {
    func test_init_rendersNameAndNoMessagesBeforeAppear() {
        let (sut, chatLoader, lineLoader, _, _) = makeSUT()

        XCTAssertEqual(sut.title, "Sprout")
        XCTAssertEqual(sut.bubbles.count, 0)
        XCTAssertEqual(chatLoader.sentTexts, [])
        XCTAssertEqual(lineLoader.requests, [])
    }

    func test_appear_rendersMoodLabelAndFaceLive() {
        let (sut, _, _, factsLoader, _) = makeSUT()

        sut.simulateAppear()
        factsLoader.completeLoad(with: makeFacts(mood: .veryThirsty))

        XCTAssertEqual(sut.subtitle, "Very thirsty")
        XCTAssertEqual(sut.renderedFace, FaceStub(mood: .veryThirsty))

        factsLoader.simulateUpdate()
        factsLoader.completeLoad(with: makeFacts(mood: .happy), at: 1)

        XCTAssertEqual(sut.subtitle, "Happy")
        XCTAssertEqual(sut.renderedFace, FaceStub(mood: .happy))
    }

    func test_appear_rendersGreetingFromPlant() {
        let (sut, _, lineLoader, factsLoader, _) = makeSUT()

        sut.simulateAppear()
        factsLoader.completeLoad(with: makeFacts())
        lineLoader.complete(with: "Hello, human!")

        XCTAssertEqual(sut.bubbles.map(\.text), ["Hello, human!"])
        XCTAssertEqual(sut.bubbles.map(\.sender), [.plant])
    }

    func test_send_rendersYourBubbleThenTypingThenReply() {
        let (sut, chatLoader, lineLoader, factsLoader, _) = makeSUT()
        sut.simulateAppear()
        factsLoader.completeLoad(with: makeFacts())
        lineLoader.complete(with: "Hi!")

        sut.simulateSend("How are you?")

        XCTAssertEqual(chatLoader.sentTexts, ["How are you?"])
        XCTAssertEqual(sut.bubbles.map(\.text), ["Hi!", "How are you?", "…"])
        XCTAssertEqual(sut.bubbles.map(\.sender), [.plant, .user, .plant])
        XCTAssertFalse(sut.canSend)

        chatLoader.complete(with: "Thirsty!")

        XCTAssertEqual(sut.bubbles.map(\.text), ["Hi!", "How are you?", "Thirsty!"])
    }

    func test_send_isDisabledWhileDraftIsEmpty() {
        let (sut, _, _, _, _) = makeSUT()

        XCTAssertFalse(sut.canSend)
    }

    func test_appear_rendersNoNoticeWhenModelIsAvailable() {
        let (sut, _, _, _, _) = makeSUT(isAvailable: true)

        sut.simulateAppear()

        XCTAssertNil(sut.notice)
    }

    func test_appear_rendersNoticeWhenModelIsUnavailable() {
        let (sut, _, _, _, _) = makeSUT(isAvailable: false)

        sut.simulateAppear()

        XCTAssertEqual(sut.notice, "Sprout's voice needs Apple Intelligence. Replies are simple for now.")
    }

    func test_personalityMenu_listsEveryPersonalityWithSavedOneChecked() {
        let (sut, _, _, _, _) = makeSUT(savedPersonality: .dramatic)

        sut.simulateAppear()

        XCTAssertEqual(sut.personalityOptions.map(\.label), ["Cheerful", "Dramatic", "Grumpy grandma", "Chill surfer", "Polite butler"])
        XCTAssertEqual(sut.personalityOptions.filter(\.isSelected).map(\.label), ["Dramatic"])
    }

    func test_selectingPersonality_savesItRestartsChatAndGreetsAgain() {
        let (sut, chatLoader, lineLoader, factsLoader, defaults) = makeSUT()
        sut.simulateAppear()
        factsLoader.completeLoad(with: makeFacts())
        lineLoader.complete(with: "Hi!")

        sut.simulatePersonalitySelection("Chill surfer")

        XCTAssertEqual(defaults.savedStrings["plant.chat.personality"], "chillSurfer")
        XCTAssertEqual(chatLoader.resetCount, 1)
        XCTAssertEqual(sut.bubbles.count, 0)
        factsLoader.completeLoad(with: makeFacts(), at: 1)
        XCTAssertEqual(lineLoader.requests.count, 2)
        XCTAssertEqual(sut.personalityOptions.filter(\.isSelected).map(\.label), ["Chill surfer"])

        lineLoader.complete(with: "Dude, hey.", at: 1)

        XCTAssertEqual(sut.bubbles.map(\.text), ["Dude, hey."])
    }

    func test_backTap_sendsBackAction() {
        var actions: [PlantChatAction] = []
        let (sut, _, _, _, _) = makeSUT(actionHandler: { actions.append($0) })

        sut.simulateBackTap()

        XCTAssertEqual(actions, [.backTap])
    }
}
