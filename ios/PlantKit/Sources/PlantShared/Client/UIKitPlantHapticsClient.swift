#if os(iOS)
import UIKit

/// One light, one soft and one notification generator, created once and reused.
@MainActor
public final class UIKitPlantHapticsClient: PlantHapticsClient {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    public init() {}

    public func play(_ haptic: PlantHaptic) {
        switch haptic {
        case .tap: light.impactOccurred()
        case .bump: soft.impactOccurred()
        case .success: notification.notificationOccurred(.success)
        case .selection: selection.selectionChanged()
        }
    }
}
#endif
