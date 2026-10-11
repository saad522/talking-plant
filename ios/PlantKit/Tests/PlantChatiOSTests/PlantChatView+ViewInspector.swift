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

    var personalityOptions: [PlantChatPersonalityMenuView.Option] {
        (try? inspect().find(PlantChatPersonalityMenuView.self).actualView().options) ?? []
    }

    var canSend: Bool {
        (try? inspect().find(PlantChatInputView.self).actualView().canSend) ?? false
    }

    func simulateAppear() {
        try? inspect().vStack().callOnAppear()
    }

    func simulateSend(_ text: String) {
        try? inspect().find(ViewType.TextField.self).setInput(text)
        try? inspect().find(PlantChatInputView.self).find(ViewType.Button.self).tap()
    }

    func simulateBackTap() {
        try? inspect().find(PlantChatHeaderView.self).find(ViewType.Button.self).tap()
    }

    func simulatePersonalitySelection(_ label: String) {
        let button = try? inspect().find(ViewType.Menu.self).findAll(ViewType.Button.self)
            .first { (try? $0.labelView().find(ViewType.Text.self).string()) == label }
        try? button?.tap()
    }
}
