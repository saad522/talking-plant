/// Tells home when the phone was shaken. The app adapts the device's shake gesture to this.
@MainActor
public protocol PlantShakeLoader {
    func subscribe(update: @escaping () -> Void)
}
