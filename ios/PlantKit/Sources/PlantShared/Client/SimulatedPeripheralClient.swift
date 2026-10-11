import Foundation

/// A fake plant that sends real 16-byte Readings packets per `docs/BLE_CONTRACT.md`.
/// Soil slowly dries, light follows a day curve, temperature and humidity swing a little.
/// Deterministic: the same ticks always produce the same packets.
@MainActor
public final class SimulatedPeripheralClient: PeripheralClient {
    /// Calls `tick` every `interval` seconds until `tick` returns `false`.
    public typealias Schedule = @MainActor (_ interval: TimeInterval, _ tick: @escaping @MainActor @Sendable () -> Bool) -> Void

    public enum Error: Swift.Error, Equatable {
        case unsupportedCharacteristic
    }

    static let wetMillivolts: Double = 1_100
    static let driestMillivolts: Double = 2_600
    static let dryingMillivoltsPerHour: Double = 18
    static let peakLux: Double = 2_000
    static let startSeconds: Double = 8 * 3_600   // 08:00
    private static let validFlags: UInt8 = 0b0111 // soil, light, environment

    private let tickInterval: TimeInterval
    private let timeScale: Double
    private let schedule: Schedule

    private var simulatedSeconds = startSeconds
    private var soilMillivolts = wetMillivolts
    private var sequence: UInt32 = 0
    private var subscriptions: [(PeripheralClient.Result) -> Void] = []
    private var isTicking = false

    /// - Parameters:
    ///   - tickInterval: Real seconds between readings.
    ///   - timeScale: Simulated seconds per real second. 720 = one simulated hour every 5 seconds.
    ///   - schedule: Drives the ticks. Tests inject their own to tick without waiting.
    public init(
        tickInterval: TimeInterval = 2,
        timeScale: Double = 720,
        schedule: @escaping Schedule = SimulatedPeripheralClient.repeatingTimer
    ) {
        self.tickInterval = tickInterval
        self.timeScale = timeScale
        self.schedule = schedule
    }

    public func read(_ characteristic: PlantCharacteristic, completion: @escaping (PeripheralClient.Result) -> Void) {
        guard characteristic == .readings else {
            return completion(.failure(Error.unsupportedCharacteristic))
        }

        completion(.success(makePacket()))
    }

    public func subscribe(to characteristic: PlantCharacteristic, update: @escaping (PeripheralClient.Result) -> Void) {
        guard characteristic == .readings else {
            return update(.failure(Error.unsupportedCharacteristic))
        }

        subscriptions.append(update)
        update(.success(makePacket()))
        startTicking()
    }

    public func write(_ data: Data, to characteristic: PlantCharacteristic, completion: @escaping (PeripheralClient.WriteResult) -> Void) {
        completion(Error.unsupportedCharacteristic)
    }

    /// Resets the soil to wet. The next reading reflects it.
    public func water() {
        soilMillivolts = Self.wetMillivolts
    }

    public static func repeatingTimer(interval: TimeInterval, tick: @escaping @MainActor @Sendable () -> Bool) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            let keepTicking = MainActor.assumeIsolated { tick() }
            if !keepTicking {
                timer.invalidate()
            }
        }
    }

    // MARK: - Private

    private func startTicking() {
        guard !isTicking else { return }
        isTicking = true

        schedule(tickInterval) { [weak self] in
            guard let self else { return false }
            self.tick()
            return true
        }
    }

    private func tick() {
        let elapsed = tickInterval * timeScale
        simulatedSeconds += elapsed
        soilMillivolts = min(soilMillivolts + Self.dryingMillivoltsPerHour * elapsed / 3_600, Self.driestMillivolts)
        sequence &+= 1

        let packet = makePacket()
        subscriptions.forEach { $0(.success(packet)) }
    }

    private func makePacket() -> Data {
        let hour = (simulatedSeconds / 3_600).truncatingRemainder(dividingBy: 24)
        let daylight = max(0, sin(.pi * (hour - 6) / 12))   // 06:00 to 18:00, peak at noon
        let warmth = sin(2 * .pi * (hour - 9) / 24)         // warmest at 15:00

        let lux = UInt16((Self.peakLux * daylight).rounded())
        let temperatureCenti = Int16(((21 + 2 * warmth) * 100).rounded())
        let humidityCenti = UInt16(((50 - 5 * warmth) * 100).rounded())

        var data = Data([PlantBluetoothContract.protocolVersion, Self.validFlags])
        [UInt16(soilMillivolts.rounded()), lux, UInt16(bitPattern: temperatureCenti), humidityCenti, 0]
            .forEach { value in withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        withUnsafeBytes(of: sequence.littleEndian) { data.append(contentsOf: $0) }
        return data
    }
}
