import PlantChatiOS
import SwiftUI
import ViewInspector

extension PlantChatView where Face == FaceStub {
    var title: String? {
        try? inspect().find(PlantChatHeaderView.self).actualView().title
    }

    var subtitle: String? {
        try? inspect().find(PlantChatHeaderView.self).actualView().subtitle
    }

    var renderedFace: FaceStub? {
        try? inspect().find(FaceStub.self).actualView()
    }

    var notice: String? {
        try? inspect().find(PlantChatNoticeView.self).actualView().text
    }

    /// The conversation as shown, including the "…" bubble while a reply is pending.
    var bubbles: [PlantChatBubbleView] {
        (try? inspect().findAll(PlantChatBubbleView.self).map { try $0.actualView() }) ?? []
    }

    var microphoneNotice: String? {
        try? inspect().find(PlantChatMicrophoneNoticeView.self).actualView().text
    }

    var microphoneNoticeButtonLabel: String? {
        try? inspect().find(PlantChatMicrophoneNoticeView.self).actualView().settingsLabel
    }

    var hasVoiceControls: Bool {
        (try? inspect().find(PlantChatVoiceControlsView.self)) != nil
    }

    var hasTextField: Bool {
        (try? inspect().find(ViewType.TextField.self)) != nil
    }

    var micIsDisabled: Bool {
        (try? voiceButtons()[1].isDisabled()) ?? false
    }

    var personalityOptions: [PlantChatPersonalityMenuView.Option] {
        (try? inspect().find(PlantChatPersonalityMenuView.self).actualView().options) ?? []
    }

    var speakReplies: PlantChatPersonalityMenuView.SpeakReplies? {
        try? inspect().find(PlantChatPersonalityMenuView.self).actualView().speakReplies
    }

    var micLabel: String? {
        try? inspect().find(PlantChatVoiceControlsView.self).actualView().micLabel
    }

    var canSend: Bool {
        (try? inspect().find(PlantChatInputView.self).actualView().canSend) ?? false
    }

    private func voiceButtons() throws -> [InspectableView<ViewType.Button>] {
        try inspect().find(PlantChatVoiceControlsView.self).findAll(ViewType.Button.self)
    }

    func simulateAppear() {
        try? inspect().vStack().callOnAppear()
    }

    func simulateSend(_ text: String) {
        if hasVoiceControls { simulateKeyboardTap() }
        try? inspect().find(ViewType.TextField.self).setInput(text)
        try? inspect().find(PlantChatInputView.self).findAll(ViewType.Button.self)[1].tap()
    }

    func simulateKeyboardTap() {
        try? voiceButtons()[0].tap()
    }

    func simulateMicTap() {
        try? voiceButtons()[1].tap()
    }

    func simulateEndTap() {
        try? voiceButtons()[2].tap()
    }

    /// The mic inside the keyboard-mode input.
    func simulateVoiceTap() {
        try? inspect().find(PlantChatInputView.self).findAll(ViewType.Button.self)[0].tap()
    }

    func simulateOpenSettingsTap() {
        try? inspect().find(PlantChatMicrophoneNoticeView.self).find(ViewType.Button.self).tap()
    }

    func simulateBackTap() {
        try? inspect().find(PlantChatHeaderView.self).find(ViewType.Button.self).tap()
    }

    func simulateSpeakRepliesToggle() {
        try? inspect().find(ViewType.Menu.self).find(ViewType.Toggle.self).tap()
    }

    func simulateVoiceSpikeTap() {
        try? inspect().find(PlantChatPersonalityMenuView.self).actualView().voiceSpike?()
    }

    func simulatePersonalitySelection(_ label: String) {
        let button = try? inspect().find(ViewType.Menu.self).findAll(ViewType.Button.self)
            .first { (try? $0.labelView().find(ViewType.Text.self).string()) == label }
        try? button?.tap()
    }
}
