#if DEBUG
import Combine
import CoreBluetooth
import Foundation
import os
import PlantShared

/// A fake board over real radio: advertises `TalkingPlant-TEST` with the Plant Service, serves
/// the three characteristics, and notifies a Readings packet every interval and on `READ_NOW`.
/// Packets come from a `SimulatedPeripheralClient`, so they are real 16-byte contract packets.
///
/// Concurrency rules (same as `CoreBluetoothPeripheralClient`, the M5b lesson):
/// 1. The `CBPeripheralManager` is created with `queue: nil`, so every delegate callback
///    arrives on the main queue.
/// 2. Every delegate method is `nonisolated`. It first copies out Sendable values (UUIDs,
///    `Data`, offsets, the error), then calls `MainActor.assumeIsolated` with only those values.
///    ATT requests are answered in the nonisolated method, from what the main actor returned.
/// 3. No `Task { @MainActor in }` hops in delegate methods.
/// 4. No closure-based system API here. Ticks use `SimulatedPeripheralClient.repeatingTimer`.
/// 5. All CoreBluetooth code lives in PlantKit, never in the app target.
@MainActor
public final class CoreBluetoothPlantTestPeripheral: NSObject, ObservableObject {
    public enum Status: Equatable, Sendable {
        case stopped
        case unsupported
        case unauthorized
        case poweredOff
        case advertising
    }

    public static let localName = PlantBluetoothContract.localNamePrefix + "TEST"
    private static let logLimit = 30

    nonisolated private static let logger = Logger(subsystem: "TalkingPlant", category: "TestPeripheral")

    @Published public private(set) var status: Status = .stopped
    @Published public private(set) var subscriberCount = 0
    @Published public private(set) var intervalSeconds = PlantTestPeripheralResponder.defaultIntervalSeconds
    @Published public private(set) var soilOverrideMillivolts: UInt16?
    /// Newest first.
    @Published public private(set) var log: [String] = []

    private let schedule: SimulatedPeripheralClient.Schedule
    private var responder = PlantTestPeripheralResponder()
    private var manager: CBPeripheralManager?
    private var plant: SimulatedPeripheralClient?
    private var advanceReading: (@MainActor @Sendable () -> Bool)?
    private var latestPacket = Data()
    private var needsResend = false
    private var tickGeneration = 0
    private var readingsCharacteristic: CBMutableCharacteristic?

    public init(schedule: @escaping SimulatedPeripheralClient.Schedule = SimulatedPeripheralClient.repeatingTimer) {
        self.schedule = schedule
        super.init()
    }

    /// Creates the peripheral manager, which shows the Bluetooth permission prompt.
    public func start() {
        guard manager == nil else { return }
        let plant = SimulatedPeripheralClient(
            tickInterval: 30,
            timeScale: 120,
            schedule: { [weak self] _, tick in self?.advanceReading = tick }
        )
        self.plant = plant
        plant.subscribe(to: .readings) { [weak self] result in
            guard case .success(let packet) = result else { return }
            self?.publish(packet)
        }
        manager = CBPeripheralManager(
            delegate: self,
            queue: nil,
            options: [CBPeripheralManagerOptionShowPowerAlertKey: false]
        )
        restartTicks()
    }

    /// Resets the soil to wet; the next reading shows it.
    public func water() {
        plant?.water()
        append("water")
    }

    /// Serves this soil value in every Readings packet; `nil` goes back to the simulated soil.
    public func setSoilOverride(_ millivolts: UInt16?) {
        responder.soilOverrideMillivolts = millivolts
        soilOverrideMillivolts = millivolts
        append(millivolts.map { "soil override \($0) mV" } ?? "soil override off")
    }

    // MARK: - Readings

    private func restartTicks() {
        tickGeneration += 1
        let generation = tickGeneration
        schedule(TimeInterval(responder.intervalSeconds)) { [weak self] in
            guard let self, self.tickGeneration == generation else { return false }
            self.nextReading()
            return true
        }
    }

    private func nextReading() {
        _ = advanceReading?()
    }

    private func publish(_ packet: Data) {
        latestPacket = packet
        notifySubscribers()
    }

    private func notifySubscribers() {
        guard subscriberCount > 0, let manager, let readingsCharacteristic else { return }
        needsResend = !manager.updateValue(responder.readings(from: latestPacket), for: readingsCharacteristic, onSubscribedCentrals: nil)
    }

    // MARK: - Delegate events (main actor, Sendable inputs only)

    private func handleStateUpdate(_ newState: CBManagerState) {
        Self.logger.info("manager state \(newState.rawValue)")
        switch newState {
        case .poweredOn:
            addService()
        case .unsupported:
            status = .unsupported
        case .unauthorized:
            status = .unauthorized
        case .poweredOff:
            status = .poweredOff
            subscriberCount = 0
        case .unknown, .resetting:
            status = .stopped
        @unknown default:
            status = .unsupported
        }
    }

    private func addService() {
        guard let manager else { return }
        let readings = CBMutableCharacteristic(
            type: Self.cbUUID(.readings), properties: [.read, .notify], value: nil, permissions: [.readable]
        )
        let deviceInfo = CBMutableCharacteristic(
            type: Self.cbUUID(.deviceInfo), properties: [.read], value: nil, permissions: [.readable]
        )
        let command = CBMutableCharacteristic(
            type: Self.cbUUID(.command), properties: [.write], value: nil, permissions: [.writeable]
        )
        let service = CBMutableService(type: CBUUID(nsuuid: PlantBluetoothContract.serviceUUID), primary: true)
        service.characteristics = [readings, deviceInfo, command]
        readingsCharacteristic = readings
        manager.removeAllServices()
        manager.add(service)
    }

    private func handleServiceAdded(error: (any Error)?) {
        guard let manager else { return }
        if let error {
            Self.logger.error("add service failed: \(error.localizedDescription)")
            append("add service failed: \(error.localizedDescription)")
            return
        }
        manager.startAdvertising([
            CBAdvertisementDataLocalNameKey: Self.localName,
            CBAdvertisementDataServiceUUIDsKey: [CBUUID(nsuuid: PlantBluetoothContract.serviceUUID)]
        ])
    }

    private func handleAdvertisingStarted(error: (any Error)?) {
        if let error {
            Self.logger.error("advertising failed: \(error.localizedDescription)")
            append("advertising failed: \(error.localizedDescription)")
            return
        }
        status = .advertising
        append("advertising as \(Self.localName)")
    }

    private func handleSubscription(_ characteristicUUID: UUID?, isSubscribed: Bool) {
        guard characteristicUUID == PlantCharacteristic.readings.uuid else { return }
        subscriberCount = max(0, subscriberCount + (isSubscribed ? 1 : -1))
        append(isSubscribed ? "central subscribed to Readings" : "central unsubscribed from Readings")
    }

    private func handleRead(_ characteristicUUID: UUID?, offset: Int) -> (value: Data?, result: CBATTError.Code) {
        let value: Data
        switch characteristicUUID.flatMap(PlantCharacteristic.init(uuid:)) {
        case .readings: value = responder.readings(from: latestPacket)
        case .deviceInfo: value = responder.deviceInfo
        case .command, nil: return (nil, .readNotPermitted)
        }
        guard offset <= value.count else { return (nil, .invalidOffset) }
        append("read \(characteristicUUID.flatMap(PlantCharacteristic.init(uuid:)).map(String.init(describing:)) ?? "?")")
        return (value.subdata(in: offset..<value.count), .success)
    }

    private func handleWrite(_ writes: [(characteristicUUID: UUID?, value: Data?)]) -> CBATTError.Code {
        for write in writes {
            guard write.characteristicUUID == PlantCharacteristic.command.uuid else { return .writeNotPermitted }
            apply(command: write.value ?? Data())
        }
        return .success
    }

    private func apply(command: Data) {
        let hex = command.map { String(format: "%02X", $0) }.joined(separator: " ")
        switch responder.handle(command: command) {
        case .readNow:
            append("READ_NOW")
            nextReading()
        case .setInterval(let seconds):
            append("SET_INTERVAL \(seconds) s")
            intervalSeconds = seconds
            restartTicks()
        case .ignored:
            append("ignored command [\(hex)]")
        }
    }

    private func handleReadyToUpdate() {
        guard needsResend else { return }
        notifySubscribers()
    }

    private func append(_ line: String) {
        Self.logger.info("\(line)")
        log.insert(line, at: 0)
        if log.count > Self.logLimit { log.removeLast(log.count - Self.logLimit) }
    }

    nonisolated private static func uuid(_ cbUUID: CBUUID) -> UUID? {
        UUID(uuidString: cbUUID.uuidString)
    }

    nonisolated private static func cbUUID(_ characteristic: PlantCharacteristic) -> CBUUID {
        CBUUID(nsuuid: characteristic.uuid)
    }
}

// MARK: - CBPeripheralManagerDelegate

extension CoreBluetoothPlantTestPeripheral: CBPeripheralManagerDelegate {
    nonisolated public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let newState = peripheral.state
        MainActor.assumeIsolated {
            handleStateUpdate(newState)
        }
    }

    nonisolated public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: (any Error)?) {
        MainActor.assumeIsolated {
            handleServiceAdded(error: error)
        }
    }

    nonisolated public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        MainActor.assumeIsolated {
            handleAdvertisingStarted(error: error)
        }
    }

    nonisolated public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        let characteristicUUID = Self.uuid(characteristic.uuid)
        MainActor.assumeIsolated {
            handleSubscription(characteristicUUID, isSubscribed: true)
        }
    }

    nonisolated public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        let characteristicUUID = Self.uuid(characteristic.uuid)
        MainActor.assumeIsolated {
            handleSubscription(characteristicUUID, isSubscribed: false)
        }
    }

    nonisolated public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        let characteristicUUID = Self.uuid(request.characteristic.uuid)
        let offset = request.offset
        let answer = MainActor.assumeIsolated {
            handleRead(characteristicUUID, offset: offset)
        }
        request.value = answer.value
        peripheral.respond(to: request, withResult: answer.result)
    }

    nonisolated public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        let writes = requests.map { (characteristicUUID: Self.uuid($0.characteristic.uuid), value: $0.value) }
        let result = MainActor.assumeIsolated {
            handleWrite(writes)
        }
        // CoreBluetooth wants one response for the whole batch, through its first request.
        if let first = requests.first {
            peripheral.respond(to: first, withResult: result)
        }
    }

    nonisolated public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        MainActor.assumeIsolated {
            handleReadyToUpdate()
        }
    }
}
#endif
