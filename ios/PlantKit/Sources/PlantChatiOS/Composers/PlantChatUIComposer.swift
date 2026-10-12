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

        viewModel.loadedPersonality = { [weak store, weak viewModel] personality in
            store?.personalityMenu = makeMenu(current: personality, viewModel: viewModel)
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

    private static func makeMenu(current: PlantPersonality, viewModel: PlantChatViewModel?) -> PlantChatPersonalityMenuView {
        PlantChatPersonalityMenuView(
            accessibilityLabel: viewModel?.personalityLabel ?? "",
            options: (viewModel?.personalities ?? []).map { option in
                PlantChatPersonalityMenuView.Option(
                    id: option.personality.rawValue,
                    label: option.label,
                    isSelected: option.personality == current,
                    select: { [weak viewModel] in viewModel?.select(option.personality) }
                )
            }
        )
    }
}
