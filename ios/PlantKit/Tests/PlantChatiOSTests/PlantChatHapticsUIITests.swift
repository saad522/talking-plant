@testable import PlantChatiOS
import PlantChat
import PlantShared
import XCTest

@MainActor
final class PlantChatHapticsUIITests: PlantChatiOSXCTestCase {
    func test_appear_andIncomingMessages_playNoHaptic() {
        let haptics = HapticsSpy()
        let (sut, _, lineLoader, factsLoader, _) = makeSUT(haptics: haptics)

        sut.simulateAppear()
        factsLoader.completeLoad(with: makeFacts())
        lineLoader.complete(with: "Hi!")

        XCTAssertEqual(haptics.played, [])
    }

    func test_backTap_playsTapAndStillSendsBack() {
        var actions: [PlantChatAction] = []
        let haptics = HapticsSpy()
        let (sut, _, _, _, _) = makeSUT(haptics: haptics, actionHandler: { actions.append($0) })

        sut.simulateBackTap()

        XCTAssertEqual(haptics.played, [.tap])
        XCTAssertEqual(actions, [.backTap])
    }

    func test_endTap_playsOneTapAndStillSendsBack() {
        var actions: [PlantChatAction] = []
        let haptics = HapticsSpy()
        let (sut, _, _, _, _) = makeSUT(haptics: haptics, actionHandler: { actions.append($0) })
        sut.simulateAppear()

        sut.simulateEndTap()

        XCTAssertEqual(haptics.played, [.tap])
        XCTAssertEqual(actions, [.backTap])
    }

    func test_keyboardTap_andItsMicTap_playTapEach() {
        let haptics = HapticsSpy()
        let (sut, _, _, _, _) = makeSUT(haptics: haptics)
        sut.simulateAppear()

        sut.simulateKeyboardTap()
        XCTAssertEqual(haptics.played, [.tap])
        XCTAssertTrue(sut.hasTextField)

        sut.simulateVoiceTap()
        XCTAssertEqual(haptics.played, [.tap, .tap])
        XCTAssertTrue(sut.hasVoiceControls)
    }

    func test_send_playsOneTapAndSendsText() {
        let haptics = HapticsSpy()
        let (sut, chatLoader, lineLoader, factsLoader, _) = makeSUT(haptics: haptics)
        sut.simulateAppear()
        factsLoader.completeLoad(with: makeFacts())
        lineLoader.complete(with: "Hi!")
        sut.simulateKeyboardTap()
        let beforeSend = haptics.played

        sut.simulateSend("Hello")

        XCTAssertEqual(Array(haptics.played.dropFirst(beforeSend.count)), [.tap])
        XCTAssertEqual(chatLoader.sentTexts, ["Hello"])
    }

    func test_typing_playsNoHaptic() {
        let haptics = HapticsSpy()
        let (sut, _, _, _, _) = makeSUT(haptics: haptics)
        sut.simulateAppear()
        sut.simulateKeyboardTap()
        haptics.clear()

        sut.simulateTyping("Hel")

        XCTAssertEqual(haptics.played, [])
    }

    func test_micTap_playsBumpWhenListeningStartsAndTapWhenItStops() {
        let transcriptLoader = TranscriptLoaderStub()
        let haptics = HapticsSpy()
        let (sut, _, _, factsLoader, _) = makeSUT(transcriptLoader: transcriptLoader, haptics: haptics)
        sut.simulateAppear()
        factsLoader.completeLoad(with: makeFacts())

        sut.simulateMicTap()
        XCTAssertEqual(haptics.played, [.bump])

        transcriptLoader.sendPartial("How are")
        XCTAssertEqual(haptics.played, [.bump], "Partial transcripts are data updates")

        sut.simulateMicTap()
        XCTAssertEqual(haptics.played, [.bump, .tap])
    }

    func test_micTap_whileSpeaking_playsOneBumpAsListeningRestarts() {
        let transcriptLoader = TranscriptLoaderStub()
        let synthesizer = SynthesizerSpy()
        let haptics = HapticsSpy()
        let (sut, chatLoader, _, factsLoader, _) = makeSUT(transcriptLoader: transcriptLoader, synthesizer: synthesizer, haptics: haptics)
        sut.simulateAppear()
        factsLoader.completeLoad(with: makeFacts())
        sut.simulateMicTap()
        transcriptLoader.sendFinal("How are you?")
        chatLoader.complete(with: "Thirsty!")
        haptics.clear()

        sut.simulateMicTap()

        XCTAssertEqual(haptics.played, [.bump])
    }

    func test_micTap_whenPermissionDenied_playsNoBump() {
        let transcriptLoader = TranscriptLoaderStub()
        transcriptLoader.authorization = .denied
        let haptics = HapticsSpy()
        let (sut, _, _, _, _) = makeSUT(transcriptLoader: transcriptLoader, haptics: haptics)
        sut.simulateAppear()

        sut.simulateMicTap()

        XCTAssertFalse(haptics.played.contains(.bump))
    }

    func test_openSettingsTap_playsTapAndStillSendsAction() {
        let transcriptLoader = TranscriptLoaderStub()
        transcriptLoader.authorization = .denied
        var actions: [PlantChatAction] = []
        let haptics = HapticsSpy()
        let (sut, _, _, _, _) = makeSUT(transcriptLoader: transcriptLoader, haptics: haptics, actionHandler: { actions.append($0) })
        sut.simulateAppear()

        sut.simulateOpenSettingsTap()

        XCTAssertEqual(haptics.played, [.tap])
        XCTAssertEqual(actions, [.openSettings])
    }

    func test_speakRepliesToggle_playsSelectionAndStillSaves() {
        let haptics = HapticsSpy()
        let (sut, _, _, _, defaults) = makeSUT(haptics: haptics)
        sut.simulateAppear()

        sut.simulateSpeakRepliesToggle()

        XCTAssertEqual(haptics.played, [.selection])
        XCTAssertEqual(defaults.savedBools["plant.chat.spokenReplies.enabled"], false)
    }

    func test_personalityOption_playsTap() {
        let haptics = HapticsSpy()
        let (sut, _, _, _, _) = makeSUT(haptics: haptics)
        sut.simulateAppear()

        sut.personalityOptions.first?.select()

        XCTAssertEqual(haptics.played, [.tap])
    }
}
