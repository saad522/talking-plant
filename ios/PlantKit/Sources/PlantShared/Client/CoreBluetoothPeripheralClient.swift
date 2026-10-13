import CoreBluetooth
import Foundation
import os

/// The real sensor over Bluetooth LE. Thin on purpose: no timers, no interval, no version
/// check, no persistence. Those rules live in the loaders above it.
///
/// Concurrency rules (the M5b lesson: a closure inferred `@MainActor`, then called by the
/// system on a background queue):
/// 1. The `CBCentralManager` is created with `queue: nil`, so every delegate callback
///    arrives on the main queue.
/// 2. Every delegate method is `nonisolated`. It first copies out Sendable values
///    (identifiers, UUIDs, `Data`, `Int`, names, the error), then calls
///    `MainActor.assumeIsolated` with only those values. CoreBluetooth objects are looked up
///    again from this client's own stored properties, never passed across.
/// 3. No `Task { @MainActor in }` hops in delegate methods; they could reorder events.
/// 4. No closure-based system API in this client. If one is needed, call it from a
///    `nonisolated static` function.
/// 5. All CoreBluetooth code lives in PlantKit, never in the app target (its default
///    isolation is `MainActor`).
/// 6. The central manager is created in `init`, which shows the Bluetooth permission prompt.
///    Only create this client in sensor mode.
@MainActor
public final class CoreBluetoothPeripheralClient: NSObject, PeripheralClient, PeripheralConnectionClient {
    public enum Error: Swift.Error, Equatable {
        case notConnected
        case disconnected
    }

    private struct Target {
        var identifier: UUID
        var name: String
    }

    nonisolated private static let logger = Logger(subsystem: "TalkingPlant", category: "Bluetooth")

    private var central: CBCentralManager!
    private var managerState: CBManagerState = .unknown
    private var target: Target?
    private var peripheral: CBPeripheral?
    private var characteristics: [PlantCharacteristic: CBCharacteristic] = [:]

    private var pendingReads: [PlantCharacteristic: [(PeripheralClient.Result) -> Void]] = [:]
    private var pendingWrites: [PlantCharacteristic: [(PeripheralClient.WriteResult) -> Void]] = [:]
    private var subscriptions: [PlantCharacteristic: [(PeripheralClient.Result) -> Void]] = [:]

    private var stateSubscriptions: [(PeripheralConnectionState) -> Void] = []
    private var scanHandler: ((PeripheralAdvertisement) -> Void)?
    private var isScanning = false

    private var state: PeripheralConnectionState = .idle {
        didSet {
            guard state != oldValue else { return }
            Self.logger.info("state \(String(describing: oldValue)) -> \(String(describing: self.state))")
            stateSubscriptions.forEach { $0(state) }
        }
    }

    private var isPoweredOn: Bool { managerState == .poweredOn }

    private static var serviceCBUUID: CBUUID { CBUUID(nsuuid: PlantBluetoothContract.serviceUUID) }

    public override init() {
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionShowPowerAlertKey: false]
        )
    }

    // MARK: - PeripheralClient

    public func read(_ characteristic: PlantCharacteristic, completion: @escaping (PeripheralClient.Result) -> Void) {
        guard state == .connected, let peripheral, let cbCharacteristic = characteristics[characteristic] else {
            completion(.failure(Error.notConnected))
            return
        }
        pendingReads[characteristic, default: []].append(completion)
        peripheral.readValue(for: cbCharacteristic)
    }

    public func subscribe(to characteristic: PlantCharacteristic, update: @escaping (PeripheralClient.Result) -> Void) {
        subscriptions[characteristic, default: []].append(update)
        if state == .connected, let peripheral, let cbCharacteristic = characteristics[characteristic] {
            peripheral.setNotifyValue(true, for: cbCharacteristic)
        }
    }

    public func write(_ data: Data, to characteristic: PlantCharacteristic, completion: @escaping (PeripheralClient.WriteResult) -> Void) {
        guard state == .connected, let peripheral, let cbCharacteristic = characteristics[characteristic] else {
            completion(Error.notConnected)
            return
        }
        pendingWrites[characteristic, default: []].append(completion)
        peripheral.writeValue(data, for: cbCharacteristic, type: .withResponse)
    }

    // MARK: - PeripheralConnectionClient

    public func subscribe(state update: @escaping (PeripheralConnectionState) -> Void) {
        stateSubscriptions.append(update)
        update(state)
    }

    public func scan(update: @escaping (PeripheralAdvertisement) -> Void) {
        scanHandler = update
        updateScanning()
    }

    public func stopScan() {
        scanHandler = nil
        updateScanning()
    }

    public func connect(to identifier: UUID, name: String) {
        Self.logger.info("connect to \(identifier.uuidString) \(name)")
        if let peripheral, peripheral.identifier == identifier, state != .incompatible {
            target = Target(identifier: identifier, name: name)
            return
        }
        dropPeripheral(cancel: true)
        target = Target(identifier: identifier, name: name)
        startConnecting()
    }

    public func disconnect() {
        Self.logger.info("disconnect")
        target = nil
        dropPeripheral(cancel: true)
        updateScanning()
        if isPoweredOn { state = .idle }
    }

    // MARK: - Connection steps (main actor)

    private func startConnecting() {
        guard isPoweredOn, let target else { return }
        state = .connecting
        if let known = central.retrievePeripherals(withIdentifiers: [target.identifier]).first {
            adopt(known)
        } else {
            Self.logger.info("identifier unknown to this phone, scanning for \(target.name)")
        }
        updateScanning()
    }

    private func adopt(_ newPeripheral: CBPeripheral) {
        peripheral = newPeripheral
        newPeripheral.delegate = self
        Self.logger.info("connecting to \(newPeripheral.identifier.uuidString)")
        central.connect(newPeripheral, options: nil)
    }

    private func dropPeripheral(cancel: Bool) {
        if cancel, let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        characteristics = [:]
        failPendingRequests()
    }

    private func failPendingRequests() {
        let reads = pendingReads
        let writes = pendingWrites
        pendingReads = [:]
        pendingWrites = [:]
        reads.values.joined().forEach { $0(.failure(Error.disconnected)) }
        writes.values.joined().forEach { $0(Error.disconnected) }
    }

    private func updateScanning() {
        let needsFallbackScan = target != nil && peripheral == nil
        let shouldScan = isPoweredOn && (scanHandler != nil || needsFallbackScan)
        guard shouldScan != isScanning else { return }
        isScanning = shouldScan
        if shouldScan {
            Self.logger.info("scan start")
            central.scanForPeripherals(
                withServices: [Self.serviceCBUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        } else {
            Self.logger.info("scan stop")
            central.stopScan()
        }
    }

    private func markIncompatible(_ reason: String) {
        Self.logger.error("incompatible: \(reason)")
        if let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        characteristics = [:]
        failPendingRequests()
        state = .incompatible
    }

    private func connectionLost(_ error: (any Swift.Error)?) {
        Self.logger.info("connection lost: \(String(describing: error))")
        characteristics = [:]
        failPendingRequests()
        guard state != .incompatible, target != nil, isPoweredOn, let peripheral else { return }
        state = .connecting
        central.connect(peripheral, options: nil)
    }

    // MARK: - Delegate events (main actor, Sendable inputs only)

    private func handleStateUpdate(_ newState: CBManagerState) {
        managerState = newState
        switch newState {
        case .poweredOn:
            state = target == nil ? .idle : .connecting
            startConnecting()
        case .unsupported, .unauthorized, .poweredOff:
            dropEverything()
            state = switch newState {
            case .unsupported: .unsupported
            case .unauthorized: .unauthorized
            default: .poweredOff
            }
        case .unknown, .resetting:
            dropEverything()
            state = target == nil ? .idle : .connecting
        @unknown default:
            dropEverything()
            state = .unsupported
        }
    }

    private func dropEverything() {
        peripheral = nil
        characteristics = [:]
        isScanning = false
        failPendingRequests()
    }

    private func handleDiscovery(identifier: UUID, name: String?, rssi: Int) {
        scanHandler?(PeripheralAdvertisement(identifier: identifier, localName: name, rssi: rssi))

        guard isPoweredOn, let target, peripheral == nil,
              identifier == target.identifier || name == target.name,
              let found = central.retrievePeripherals(withIdentifiers: [identifier]).first else { return }
        self.target = Target(identifier: identifier, name: target.name)
        adopt(found)
        updateScanning()
    }

    private func handleConnected(identifier: UUID) {
        guard let peripheral, peripheral.identifier == identifier else { return }
        Self.logger.info("connected, discovering services")
        peripheral.discoverServices([Self.serviceCBUUID])
    }

    private func handleDisconnected(identifier: UUID, error: (any Swift.Error)?) {
        guard peripheral?.identifier == identifier else { return }
        connectionLost(error)
    }

    private func handleServices(identifier: UUID, error: (any Swift.Error)?) {
        guard let peripheral, peripheral.identifier == identifier else { return }
        if let error {
            Self.logger.error("service discovery failed: \(error.localizedDescription)")
        }
        guard let service = peripheral.services?.first(where: { Self.uuid($0.uuid) == PlantBluetoothContract.serviceUUID }) else {
            markIncompatible("Plant Service missing")
            return
        }
        peripheral.discoverCharacteristics(PlantCharacteristic.allCases.map { CBUUID(nsuuid: $0.uuid) }, for: service)
    }

    private func handleCharacteristics(identifier: UUID, serviceUUID: UUID?, error: (any Swift.Error)?) {
        guard let peripheral, peripheral.identifier == identifier, serviceUUID == PlantBluetoothContract.serviceUUID else { return }
        if let error {
            Self.logger.error("characteristic discovery failed: \(error.localizedDescription)")
        }
        let service = peripheral.services?.first(where: { Self.uuid($0.uuid) == PlantBluetoothContract.serviceUUID })
        var found: [PlantCharacteristic: CBCharacteristic] = [:]
        for candidate in service?.characteristics ?? [] {
            if let uuid = Self.uuid(candidate.uuid), let known = PlantCharacteristic(uuid: uuid) {
                found[known] = candidate
            }
        }
        guard found.count == PlantCharacteristic.allCases.count else {
            markIncompatible("characteristics missing: found \(found.keys.count) of \(PlantCharacteristic.allCases.count)")
            return
        }
        characteristics = found
        found[.readings].map { peripheral.setNotifyValue(true, for: $0) }
        for (characteristic, handlers) in subscriptions where characteristic != .readings && !handlers.isEmpty {
            found[characteristic].map { peripheral.setNotifyValue(true, for: $0) }
        }
    }

    private func handleNotificationState(identifier: UUID, characteristicUUID: UUID?, isNotifying: Bool, error: (any Swift.Error)?) {
        guard peripheral?.identifier == identifier else { return }
        if let error {
            Self.logger.error("notify state failed: \(error.localizedDescription)")
        }
        guard characteristicUUID == PlantCharacteristic.readings.uuid, state == .connecting, !characteristics.isEmpty else { return }
        Self.logger.info("readings notify \(isNotifying)")
        state = .connected
    }

    private func handleValue(identifier: UUID, characteristicUUID: UUID?, value: Data?, error: (any Swift.Error)?) {
        guard peripheral?.identifier == identifier,
              let characteristicUUID, let characteristic = PlantCharacteristic(uuid: characteristicUUID) else { return }
        let result: PeripheralClient.Result = if let error { .failure(error) } else { .success(value ?? Data()) }
        if let error {
            Self.logger.error("value update failed: \(error.localizedDescription)")
        }
        let reads = pendingReads.removeValue(forKey: characteristic) ?? []
        reads.forEach { $0(result) }
        (subscriptions[characteristic] ?? []).forEach { $0(result) }
    }

    private func handleWrite(identifier: UUID, characteristicUUID: UUID?, error: (any Swift.Error)?) {
        guard peripheral?.identifier == identifier,
              let characteristicUUID, let characteristic = PlantCharacteristic(uuid: characteristicUUID),
              var queue = pendingWrites[characteristic], !queue.isEmpty else { return }
        let completion = queue.removeFirst()
        pendingWrites[characteristic] = queue
        completion(error)
    }

    nonisolated private static func uuid(_ cbUUID: CBUUID) -> UUID? {
        UUID(uuidString: cbUUID.uuidString)
    }
}

// MARK: - CBCentralManagerDelegate

extension CoreBluetoothPeripheralClient: CBCentralManagerDelegate {
    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let newState = central.state
        MainActor.assumeIsolated {
            handleStateUpdate(newState)
        }
    }

    nonisolated public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let identifier = peripheral.identifier
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        let rssi = RSSI.intValue
        MainActor.assumeIsolated {
            handleDiscovery(identifier: identifier, name: name, rssi: rssi)
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let identifier = peripheral.identifier
        MainActor.assumeIsolated {
            handleConnected(identifier: identifier)
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Swift.Error)?) {
        let identifier = peripheral.identifier
        MainActor.assumeIsolated {
            handleDisconnected(identifier: identifier, error: error)
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Swift.Error)?) {
        let identifier = peripheral.identifier
        MainActor.assumeIsolated {
            handleDisconnected(identifier: identifier, error: error)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension CoreBluetoothPeripheralClient: CBPeripheralDelegate {
    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Swift.Error)?) {
        let identifier = peripheral.identifier
        MainActor.assumeIsolated {
            handleServices(identifier: identifier, error: error)
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Swift.Error)?) {
        let identifier = peripheral.identifier
        let serviceUUID = Self.uuid(service.uuid)
        MainActor.assumeIsolated {
            handleCharacteristics(identifier: identifier, serviceUUID: serviceUUID, error: error)
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Swift.Error)?) {
        let identifier = peripheral.identifier
        let characteristicUUID = Self.uuid(characteristic.uuid)
        let isNotifying = characteristic.isNotifying
        MainActor.assumeIsolated {
            handleNotificationState(identifier: identifier, characteristicUUID: characteristicUUID, isNotifying: isNotifying, error: error)
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Swift.Error)?) {
        let identifier = peripheral.identifier
        let characteristicUUID = Self.uuid(characteristic.uuid)
        let value = characteristic.value
        MainActor.assumeIsolated {
            handleValue(identifier: identifier, characteristicUUID: characteristicUUID, value: value, error: error)
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Swift.Error)?) {
        let identifier = peripheral.identifier
        let characteristicUUID = Self.uuid(characteristic.uuid)
        MainActor.assumeIsolated {
            handleWrite(identifier: identifier, characteristicUUID: characteristicUUID, error: error)
        }
    }
}
