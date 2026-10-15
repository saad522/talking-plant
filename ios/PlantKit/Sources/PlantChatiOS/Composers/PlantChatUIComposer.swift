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
        haptics: PlantHapticsClient,
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
            // Listening only starts from a mic tap, so this is that tap's one haptic.
            if store?.activity != .listening, activity == .listening {
                haptics.play(.bump)
            }
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
                    settings: {
                        haptics.play(.tap)
                        notice.settingsTap()
                    }
                )
            }
        }

        viewModel.loadedPersonality = { [weak store, weak viewModel] personality in
            store?.personality = personality
            refreshMenu(store: store, viewModel: viewModel, haptics: haptics, actionHandler: actionHandler)
        }

        viewModel.loadedSpokenReplies = { [weak store, weak viewModel] isEnabled in
            store?.isSpeakingReplies = isEnabled
            refreshMenu(store: store, viewModel: viewModel, haptics: haptics, actionHandler: actionHandler)
        }

        let controls = PlantChatControls(
            back: { [weak viewModel] in
                haptics.play(.tap)
                viewModel?.backTap()
            },
            keyboard: { [weak viewModel] in
                haptics.play(.tap)
                viewModel?.keyboardTap()
            },
            mic: { [weak store, weak viewModel] in
                // Stopping is a tap here; starting plays its bump when the activity turns to listening.
                if store?.activity == .listening { haptics.play(.tap) }
                viewModel?.micTap()
            },
            end: { [weak viewModel] in
                haptics.play(.tap)
                viewModel?.endTap()
            },
            voice: { [weak viewModel] in
                haptics.play(.tap)
                viewModel?.voiceTap()
            },
            send: { [weak viewModel] in
                haptics.play(.tap)
                viewModel?.send($0)
            }
        )

        return PlantChatView(store: store, viewModel: viewModel, controls: controls)
    }

    private static func makeBubble(_ message: PlantChatMessageViewModel) -> PlantChatBubbleView {
        PlantChatBubbleView(
            id: message.id,
            text: message.text,
            sender: message.sender == .user ? .user : .plant
        )
    }

    private static func refreshMenu<Face: View>(
        store: PlantChatStore<Face>?,
        viewModel: PlantChatViewModel?,
        haptics: PlantHapticsClient,
        actionHandler: @escaping (PlantChatAction) -> Void
    ) {
        guard let store, let current = store.personality else { return }
        store.personalityMenu = makeMenu(
            current: current,
            isSpeakingReplies: store.isSpeakingReplies,
            viewModel: viewModel,
            haptics: haptics,
            actionHandler: actionHandler
        )
    }

    private static func makeMenu(
        current: PlantPersonality,
        isSpeakingReplies: Bool,
        viewModel: PlantChatViewModel?,
        haptics: PlantHapticsClient,
        actionHandler: @escaping (PlantChatAction) -> Void
    ) -> PlantChatPersonalityMenuView {
        PlantChatPersonalityMenuView(
            accessibilityLabel: viewModel?.personalityLabel ?? "",
            options: (viewModel?.personalities ?? []).map { option in
                PlantChatPersonalityMenuView.Option(
                    id: option.personality.rawValue,
                    label: option.label,
                    isSelected: option.personality == current,
                    select: { [weak viewModel] in
                        haptics.play(.tap)
                        viewModel?.select(option.personality)
                    }
                )
            },
            speakReplies: PlantChatPersonalityMenuView.SpeakReplies(
                label: viewModel?.speakRepliesLabel ?? "",
                isOn: isSpeakingReplies,
                set: { [weak viewModel] in
                    haptics.play(.selection)
                    viewModel?.setSpokenReplies($0)
                }
            ),
            voiceCheck: voiceCheck(actionHandler: actionHandler)
        )
    }

    /// The voice check entry, DEBUG builds only.
    private static func voiceCheck(actionHandler: @escaping (PlantChatAction) -> Void) -> (() -> Void)? {
        #if DEBUG
        return { actionHandler(.voiceCheckTap) }
        #else
        return nil
        #endif
    }
}
