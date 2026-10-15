import PlantMonitor
import SwiftUI

public struct PlantMonitorView<Face: View>: View {
    @ObservedObject private var store: PlantMonitorStore<Face>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let viewModel: PlantMonitorViewModel
    private let settingsAction: () -> Void

    init(store: PlantMonitorStore<Face>, viewModel: PlantMonitorViewModel, settingsAction: @escaping () -> Void) {
        self.store = store
        self.viewModel = viewModel
        self.settingsAction = settingsAction
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PlantMonitorSize.screenSpacing) {
                PlantMonitorHeaderView(
                    title: store.title,
                    subtitle: store.subtitle,
                    settingsLabel: viewModel.settingsLabel,
                    settingsAction: settingsAction
                )
                PlantMonitorSceneView(store: store)
                actions
            }
            .padding(.bottom, PlantMonitorSize.screenSpacing)
            .frame(maxWidth: .infinity)
            // Inside the fade: content arriving or changing shape (first load) is never animated.
            .transaction(value: store.layoutKey) { $0.animation = nil }
            .animation(sceneFade, value: store.palette)
        }
        .background { store.palette.background.ignoresSafeArea().animation(sceneFade, value: store.palette) }
        .environment(\.plantMonitorPalette, store.palette)
        // Only the home screen follows the scene, so History keeps following the system.
        .toolbarColorScheme(store.palette.colorScheme)
        .overlay { store.error }
        .onAppear(perform: viewModel.appear)
    }

    /// On the content and the background only, so a scene change never animates the scroll view or the toolbar.
    private var sceneFade: Animation? {
        reduceMotion ? nil : .easeInOut(duration: PlantMonitorSize.sceneFadeDuration)
    }

    private var actions: some View {
        VStack(spacing: PlantMonitorSize.actionsSpacing) {
            if let primary = store.primaryButton {
                primary
            }
            HStack(spacing: PlantMonitorSize.actionsSpacing) {
                ForEach(store.secondaryButtons.indices, id: \.self) { index in
                    store.secondaryButtons[index]
                }
            }
        }
        .padding(.horizontal, PlantMonitorSize.actionsPadding)
    }
}
