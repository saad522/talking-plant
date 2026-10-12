import PlantChat
import SwiftUI

public struct PlantChatView<Face: View>: View {
    @ObservedObject private var store: PlantChatStore<Face>
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    private let viewModel: PlantChatViewModel

    init(store: PlantChatStore<Face>, viewModel: PlantChatViewModel) {
        self.store = store
        self.viewModel = viewModel
    }

    private var color: PlantChatColor { PlantChatColor(colorScheme) }

    public var body: some View {
        VStack(spacing: PlantChatSize.bubbleSpacing) {
            PlantChatHeaderView(
                title: store.title,
                subtitle: store.subtitle,
                backLabel: viewModel.backLabel,
                personalityMenu: store.personalityMenu,
                back: viewModel.backTap
            )
            face
            store.notice
            store.microphoneNotice
            messages
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            input
                .background(color.background)
        }
        .background { color.background.ignoresSafeArea() }
        .environment(\.plantChatColor, color)
        .navigationBarBackButtonHidden(true)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear(perform: viewModel.appear)
        .onDisappear(perform: viewModel.disappear)
        .onChange(of: scenePhase) { if scenePhase != .active { viewModel.disappear() } }
    }

    @ViewBuilder
    private var input: some View {
        switch store.inputMode {
        case .voice:
            PlantChatVoiceControlsView(
                activity: store.activity,
                keyboardLabel: viewModel.keyboardLabel,
                micLabel: store.activity == .listening ? viewModel.stopListeningLabel : viewModel.talkLabel,
                endLabel: viewModel.endLabel,
                keyboard: viewModel.keyboardTap,
                mic: viewModel.micTap,
                end: viewModel.endTap
            )
        case .keyboard:
            PlantChatInputView(
                placeholder: viewModel.placeholderLabel,
                sendLabel: viewModel.sendLabel,
                text: $store.draft,
                canSend: canSend,
                voiceLabel: viewModel.talkLabel,
                send: send,
                voice: viewModel.voiceTap
            )
        }
    }

    @ViewBuilder
    private var face: some View {
        if let face = store.face {
            face
                .scaleEffect(PlantChatSize.faceSize.width / PlantChatSize.faceDrawnWidth)
                .frame(width: PlantChatSize.faceSize.width, height: PlantChatSize.faceSize.height)
        } else {
            Color.clear.frame(width: PlantChatSize.faceSize.width, height: PlantChatSize.faceSize.height)
        }
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PlantChatSize.bubbleSpacing) {
                    ForEach(store.messages) { $0 }
                    if store.activity == .listening {
                        PlantChatBubbleView(id: -2, text: store.liveTranscript ?? viewModel.listeningLabel, sender: .user, isLive: true)
                    }
                    if store.isReplying {
                        PlantChatBubbleView(id: -1, text: "…", sender: .plant)
                    }
                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .padding(.horizontal, PlantChatSize.screenPadding)
            }
            .onChange(of: store.messages.count) { scrollToBottom(proxy) }
            .onChange(of: store.isReplying) { scrollToBottom(proxy) }
            .onChange(of: store.liveTranscript) { scrollToBottom(proxy) }
        }
    }

    private var canSend: Bool {
        store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && store.isReplying == false
    }

    private func send() {
        guard canSend else { return }
        let text = store.draft
        store.draft = ""
        viewModel.send(text)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
    }

    private static var bottomID: String { "bottom" }
}
