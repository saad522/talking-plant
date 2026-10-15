import SwiftUI

public struct PlantMonitorSceneView<Face: View>: View {
    @ObservedObject private var store: PlantMonitorStore<Face>
    @Environment(\.plantMonitorPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: PlantMonitorStore<Face>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                palette.sill.frame(height: PlantMonitorSize.sillHeight)
                palette.floor.frame(height: PlantMonitorSize.floorHeight)
            }

            store.window
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, PlantMonitorSize.windowTop)
                .padding(.trailing, PlantMonitorSize.windowTrailing)

            if let face = store.face {
                Button(action: store.sproutTap) {
                    face
                }
                .buttonStyle(.plain)
                .keyframeAnimator(initialValue: 0.0, trigger: reduceMotion ? 0 : store.shakeCount) { content, angle in
                    content.rotationEffect(.degrees(angle), anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(-8, duration: 0.15)
                        LinearKeyframe(7, duration: 0.2)
                        LinearKeyframe(-5, duration: 0.2)
                        LinearKeyframe(3, duration: 0.15)
                        LinearKeyframe(0, duration: 0.1)
                    }
                }
                .accessibilityLabel(store.sproutLabel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, PlantMonitorSize.faceBottom)
            }

            if let bubble = store.bubble {
                bubble
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, PlantMonitorSize.bubbleLeading)
                    .padding(.top, PlantMonitorSize.bubbleTop)
            }

            chips
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(PlantMonitorSize.chipInset)
        }
        .frame(height: PlantMonitorSize.sceneHeight)
        .background(palette.scene)
        .clipShape(RoundedRectangle(cornerRadius: PlantMonitorSize.sceneRadius))
        .padding(.horizontal, PlantMonitorSize.sceneMargin)
    }

    private var chips: some View {
        HStack(spacing: PlantMonitorSize.chipSpacing) {
            if let loading = store.loading {
                loading
            } else {
                ForEach(store.chips.indices, id: \.self) { index in
                    store.chips[index]
                }
            }
        }
    }
}
