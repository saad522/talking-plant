import PlantShared

@MainActor
public protocol PlantConnectionLoader {
    /// Delivers the current connection, then every change.
    func subscribe(update: @escaping (PlantConnection) -> Void)
}
