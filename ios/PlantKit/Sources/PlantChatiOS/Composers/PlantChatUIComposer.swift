import PlantChat
import PlantShared
import SwiftUI

@MainActor
public enum PlantChatUIComposer {
    public static func composed<Face: View>(
        chatLoader: PlantChatLoader,
        lineLoader: PlantVoiceLineLoader,
        factsLoader: PlantVoiceFactsLoader,
        settings: PlantPersonalitySettings,
        transcriptLoader: PlantTranscriptLoader,
        audioSession: PlantAudioSessionClient,
        synthesizer: PlantSynthesizerClient,
        spokenReplies: PlantSpokenReplySettings,
        plantName: String,
        face: @escaping (PlantMood) -> Face,
        actionHandler: @escaping (PlantChatAction) -> Void
    ) -> PlantChatView<Face> {
        let store = PlantChatStore<Face>()
        let viewModel = PlantChatViewModel(
            chatLoader: chatLoader,
            lineLoader: lineLoader,
            factsLoader: factsLoader,
            settings: settings,
            transcriptLoader: transcriptLoader,
            audioSession: audioSession,
            synthesizer: synthesizer,
            spokenReplies: spokenReplies,
            plantName: plantName,
            actionHandler: actionHandler
        )

        store.title = plantName

        viewModel.loadedMessages = { [weak store] messages in
            store?.messages = messages.map(makeBubble)
        }

        viewModel.loadedTyping = { [weak store] isTyping in
            store?.isReplying = isTyping
        }

        viewModel.loadedMood = { [weak store] mood in
            store?.subtitle = mood.label
            store?.face = face(mood.mood)
        }

        viewModel.loadedAvailability = { [weak store, weak viewModel] isAvailable in
            store?.notice = isAvailable ? nil : PlantChatNoticeView(text: viewModel?.unavailableLabel ?? "")
        }

        viewModel.loadedActivity = { [weak store] activity in
            store?.activity = activity
        }

        viewModel.loadedTranscript = { [weak store] text in
            store?.liveTranscript = text.isEmpty ? nil : text
        }

        viewModel.loadedInputMode = { [weak store] mode in
            store?.inputMode = mode
        }

        viewModel.loadedMicrophoneNotice = { [weak store] notice in
            store?.microphoneNotice = notice.map { notice in
                PlantChatMicrophoneNoticeView(
                    text: notice.text,
                    settingsLabel: notice.settingsLabel,
                    settings: notice.settingsTap
                )
            }
        }

        viewModel.loadedPersonality = { [weak store, weak viewModel] personality in
            store?.personality = personality
            refreshMenu(store: store, viewModel: viewModel)
        }

        viewModel.loadedSpokenReplies = { [weak store, weak viewModel] isEnabled in
            store?.isSpeakingReplies = isEnabled
            refreshMenu(store: store, viewModel: viewModel)
        }

        return PlantChatView(store: store, viewModel: viewModel)
    }

    private static func makeBubble(_ message: PlantChatMessageViewModel) -> PlantChatBubbleView {
        PlantChatBubbleView(
            id: message.id,
            text: message.text,
            sender: message.sender == .user ? .user : .plant
        )
    }

    private static func refreshMenu<Face: View>(store: PlantChatStore<Face>?, viewModel: PlantChatViewModel?) {
        guard let store, let current = store.personality else { return }
        store.personalityMenu = makeMenu(current: current, isSpeakingReplies: store.isSpeakingReplies, viewModel: viewModel)
    }

    private static func makeMenu(current: PlantPersonality, isSpeakingReplies: Bool, viewModel: PlantChatViewModel?) -> PlantChatPersonalityMenuView {
        PlantChatPersonalityMenuView(
            accessibilityLabel: viewModel?.personalityLabel ?? "",
            options: (viewModel?.personalities ?? []).map { option in
                PlantChatPersonalityMenuView.Option(
                    id: option.personality.rawValue,
                    label: option.label,
                    isSelected: option.personality == current,
                    select: { [weak viewModel] in viewModel?.select(option.personality) }
                )
            },
            speakReplies: PlantChatPersonalityMenuView.SpeakReplies(
                label: viewModel?.speakRepliesLabel ?? "",
                isOn: isSpeakingReplies,
                set: { [weak viewModel] in viewModel?.setSpokenReplies($0) }
            )
        )
    }
}
