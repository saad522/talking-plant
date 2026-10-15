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

        XCTAssertEqual(sut.notice, "Smart replies need Apple Intelligence. Sprout will keep it simple for now.")
    }

    func test_personalityMenu_offersOnlyCheerfulEvenWhenAnotherPersonalityIsSaved() {
        let (sut, _, _, _, _) = makeSUT(savedPersonality: .chillSurfer)

        sut.simulateAppear()

        XCTAssertEqual(sut.personalityOptions.map(\.label), ["Cheerful"])
        XCTAssertEqual(sut.personalityOptions.filter(\.isSelected).map(\.label), ["Cheerful"])
    }

    func test_personalityMenu_checksCheerfulWhenSavedPersonalityIsHidden() {
        let (sut, _, _, _, _) = makeSUT(savedPersonality: .dramatic)

        sut.simulateAppear()

        XCTAssertEqual(sut.personalityOptions.filter(\.isSelected).map(\.label), ["Cheerful"])
    }

    func test_personalityMenu_showsSpeakRepliesOnByDefaultAndTogglingSavesIt() {
        let (sut, _, _, _, defaults) = makeSUT()
        sut.simulateAppear()

        XCTAssertEqual(sut.speakReplies?.label, "Speak replies")
        XCTAssertEqual(sut.speakReplies?.isOn, true)

        sut.simulateSpeakRepliesToggle()

        XCTAssertEqual(defaults.savedBools["plant.chat.spokenReplies.enabled"], false)
        XCTAssertEqual(sut.speakReplies?.isOn, false)
    }

    func test_personalityMenu_showsSavedSpeakRepliesSetting() {
        let (sut, _, _, _, _) = makeSUT(spokenRepliesEnabled: false)

        sut.simulateAppear()

        XCTAssertEqual(sut.speakReplies?.isOn, false)
    }

    func test_personalityMenu_showsSoundEffectsOnByDefaultAndTogglingSavesIt() {
        let (sut, _, _, _, defaults) = makeSUT()
        sut.simulateAppear()

        XCTAssertEqual(sut.soundEffects?.label, "Sound effects")
        XCTAssertEqual(sut.soundEffects?.isOn, true)

        sut.simulateSoundEffectsToggle()

        XCTAssertEqual(defaults.savedBools["plant.chat.soundEffects.enabled"], false)
        XCTAssertEqual(sut.soundEffects?.isOn, false)
        XCTAssertNil(defaults.savedBools["plant.chat.spokenReplies.enabled"])
    }

    func test_personalityMenu_showsSavedSoundEffectsSetting() {
        let (sut, _, _, _, _) = makeSUT(soundEffectsEnabled: false)

        sut.simulateAppear()

        XCTAssertEqual(sut.soundEffects?.isOn, false)
    }

    #if DEBUG
    func test_personalityMenuVoiceCheckTap_sendsVoiceCheckAction() {
        var actions: [PlantChatAction] = []
        let (sut, _, _, _, _) = makeSUT(actionHandler: { actions.append($0) })
        sut.simulateAppear()

        sut.simulateVoiceCheckTap()

        XCTAssertEqual(actions, [.voiceCheckTap])
    }
    #endif

    func test_backTap_sendsBackAction() {
        var actions: [PlantChatAction] = []
        let (sut, _, _, _, _) = makeSUT(actionHandler: { actions.append($0) })

        sut.simulateBackTap()

        XCTAssertEqual(actions, [.backTap])
    }

    // MARK: - Voice

    func test_voiceMode_showsThreeButtonsAndNoTextField() {
        let (sut, _, _, _, _) = makeSUT()

        sut.simulateAppear()

        XCTAssertTrue(sut.hasVoiceControls)
        XCTAssertFalse(sut.hasTextField)
    }

    func test_keyboardTap_showsTextFieldAndItsMicReturnsToVoiceMode() {
        let (sut, _, _, _, _) = makeSUT()
        sut.simulateAppear()

        sut.simulateKeyboardTap()

        XCTAssertTrue(sut.hasTextField)
        XCTAssertFalse(sut.hasVoiceControls)

        sut.simulateVoiceTap()

        XCTAssertTrue(sut.hasVoiceControls)
        XCTAssertFalse(sut.hasTextField)
    }

    func test_micTap_startsListeningAndShowsLiveBubbleThenPartialText() {
        let transcriptLoader = TranscriptLoaderStub()
        let (sut, _, _, _, _) = makeSUT(transcriptLoader: transcriptLoader)
        sut.simulateAppear()

        sut.simulateMicTap()

        XCTAssertEqual(transcriptLoader.messages, [.prepare, .start])
        XCTAssertEqual(sut.bubbles.map(\.text), ["Listening…"])
        XCTAssertEqual(sut.bubbles.map(\.sender), [.user])
        XCTAssertEqual(sut.bubbles.map(\.isLive), [true])

        transcriptLoader.sendPartial("How are")

        XCTAssertEqual(sut.bubbles.map(\.text), ["How are"])
    }

    func test_finalTranscript_rendersYourBubbleThenTyping() {
        let transcriptLoader = TranscriptLoaderStub()
        let (sut, chatLoader, lineLoader, factsLoader, _) = makeSUT(transcriptLoader: transcriptLoader)
        sut.simulateAppear()
        factsLoader.completeLoad(with: makeFacts())
        lineLoader.complete(with: "Hi!")
        sut.simulateMicTap()
        transcriptLoader.sendPartial("How are you")

        transcriptLoader.sendFinal("How are you?")

        XCTAssertEqual(chatLoader.sentTexts, ["How are you?"])
        XCTAssertEqual(sut.bubbles.map(\.text), ["Hi!", "How are you?", "…"])
        XCTAssertEqual(sut.bubbles.map(\.isLive), [false, false, false])
    }

    func test_micLabel_whileSpeaking_isInterrupt() {
        let transcriptLoader = TranscriptLoaderStub()
        let synthesizer = SynthesizerSpy()
        let (sut, chatLoader, _, factsLoader, _) = makeSUT(transcriptLoader: transcriptLoader, synthesizer: synthesizer)
        sut.simulateAppear()
        factsLoader.completeLoad(with: makeFacts())
        XCTAssertEqual(sut.micLabel, "Talk to Sprout")
        sut.simulateMicTap()
        XCTAssertEqual(sut.micLabel, "Stop listening")
        transcriptLoader.sendFinal("How are you?")

        chatLoader.complete(with: "Thirsty!")

        XCTAssertEqual(synthesizer.speeches, ["Thirsty!"])
        XCTAssertEqual(sut.micLabel, "Interrupt Sprout")

        synthesizer.finish()

        XCTAssertEqual(sut.micLabel, "Talk to Sprout")
    }

    func test_mic_isDisabledWhileThinking() {
        let transcriptLoader = TranscriptLoaderStub()
        let (sut, chatLoader, _, factsLoader, _) = makeSUT(transcriptLoader: transcriptLoader)
        sut.simulateAppear()
        factsLoader.completeLoad(with: makeFacts())
        XCTAssertFalse(sut.micIsDisabled)
        sut.simulateMicTap()
        transcriptLoader.sendFinal("How are you?")

        XCTAssertTrue(sut.micIsDisabled)

        chatLoader.complete(with: "Thirsty!")

        XCTAssertFalse(sut.micIsDisabled)
    }

    func test_deniedAuthorization_showsNoticeWithOpenSettingsInKeyboardMode() {
        let transcriptLoader = TranscriptLoaderStub()
        transcriptLoader.authorization = .denied
        var actions: [PlantChatAction] = []
        let (sut, _, _, _, _) = makeSUT(transcriptLoader: transcriptLoader, actionHandler: { actions.append($0) })

        sut.simulateAppear()

        XCTAssertNotNil(sut.microphoneNotice)
        XCTAssertEqual(sut.microphoneNoticeButtonLabel, "Open Settings")
        XCTAssertTrue(sut.hasTextField)

        sut.simulateOpenSettingsTap()

        XCTAssertEqual(actions, [.openSettings])
    }

    func test_restrictedAndUnsupported_showNoticeWithoutButtonInKeyboardMode() {
        for authorization in [PlantSpeechAuthorization.restricted, .unsupported] {
            let transcriptLoader = TranscriptLoaderStub()
            transcriptLoader.authorization = authorization
            let (sut, _, _, _, _) = makeSUT(transcriptLoader: transcriptLoader)

            sut.simulateAppear()

            XCTAssertNotNil(sut.microphoneNotice, "\(authorization)")
            XCTAssertNil(sut.microphoneNoticeButtonLabel, "\(authorization)")
            XCTAssertTrue(sut.hasTextField, "\(authorization)")
        }
    }

    func test_endTap_sendsBackAction() {
        var actions: [PlantChatAction] = []
        let (sut, _, _, _, _) = makeSUT(actionHandler: { actions.append($0) })
        sut.simulateAppear()

        sut.simulateEndTap()

        XCTAssertEqual(actions, [.backTap])
    }
}
