//
//  DeviceShake.swift
//  TalkingPlant
//

import Combine
import Foundation
import PlantMonitor
import UIKit

extension Notification.Name {
    static let plantDeviceDidShake = Notification.Name("plant.device.didShake")
}

/// SwiftUI has no shake event, so the window posts one (docs/plans/P1-alive.md D9).
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .plantDeviceDidShake, object: nil)
        }
    }
}

/// Turns the window's shake notification into a `PlantShakeLoader`.
@MainActor
final class NotificationPlantShakeLoader: PlantShakeLoader {
    private let center: NotificationCenter
    private var subscriptions: [AnyCancellable] = []

    init(center: NotificationCenter = .default) {
        self.center = center
    }

    func subscribe(update: @escaping () -> Void) {
        subscriptions.append(center.publisher(for: .plantDeviceDidShake).sink { _ in update() })
    }
}
