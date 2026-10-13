import Foundation
import PlantShared

@MainActor
public final class PlantDeviceCalibrationViewModel {
    public typealias Observer<T> = (T) -> Void
    public typealias Schedule = @MainActor (_ interval: TimeInterval, _ tick: @escaping @MainActor @Sendable () -> Bool) -> Void

    private struct Capture {
        let point: PlantDeviceCalibrationPoint
        let baselineSequence: UInt32?
        let generation: Int
    }

    private let calibrationLoader: LocalMoistureCalibrationLoader
    private let rawReadingLoader: PlantDeviceRawReadingLoader
    private let connectionLoader: PlantDeviceConnectionLoader
    private let commandSender: PlantDeviceCommandSender
    private let captureTimeout: TimeInterval
    private let schedule: Schedule
    private var appeared = false
    private var isConnected = false
    private var latestSequence: UInt32?
    private var capture: Capture?
    private var generation = 0
    private var dryDraft: Int?
    private var wetDraft: Int?

    public let title: String = String.localised(key: "plant.device.calibration.title")
    public let statusLabel: String = String.localised(key: "plant.device.calibration.status.label")
    public let dryLabel: String = String.localised(key: "plant.device.calibration.dry.label")
    public let wetLabel: String = String.localised(key: "plant.device.calibration.wet.label")
    public let nowSectionLabel: String = String.localised(key: "plant.device.calibration.now.section")
    public let soilLabel: String = String.localised(key: "plant.device.calibration.soil.label")
    public let drySectionLabel: String = String.localised(key: "plant.device.calibration.dry.section")
    public let captureDryLabel: String = String.localised(key: "plant.device.calibration.dry.capture")
    public let dryHint: String = String.localised(key: "plant.device.calibration.dry.hint")
    public let wetSectionLabel: String = String.localised(key: "plant.device.calibration.wet.section")
    public let captureWetLabel: String = String.localised(key: "plant.device.calibration.wet.capture")
    public let wetHint: String = String.localised(key: "plant.device.calibration.wet.hint")
    public let saveLabel: String = String.localised(key: "plant.device.calibration.save")
    public let resetLabel: String = String.localised(key: "plant.device.calibration.reset")
    public let offlineHint: String = String.localised(key: "plant.device.calibration.offline")

    public var loadedStatus: Observer<PlantDeviceCalibrationStatusViewModel>?
    public var loadedLiveSoil: Observer<String>?
    /// The captured value for a point, or `nil` once the draft is cleared.
    public var loadedDraft: Observer<(point: PlantDeviceCalibrationPoint, text: String?)>?
    /// The point being captured, or `nil` when no capture is running.
    public var loadedCapturing: Observer<PlantDeviceCalibrationPoint?>?
    public var loadedCanCapture: Observer<Bool>?
    public var loadedCanSave: Observer<Bool>?
    /// The message to show, or `nil` to clear it.
    public var loadedMessage: Observer<String?>?
    public var loadedWarning: Observer<String?>?

    /// - Parameters:
    ///   - captureTimeout: How long a capture waits for a fresh reading.
    ///   - schedule: Calls `tick` after `captureTimeout`; the tick returns `false` so it runs once.
    public init(
        calibrationLoader: LocalMoistureCalibrationLoader,
        rawReadingLoader: PlantDeviceRawReadingLoader,
        connectionLoader: PlantDeviceConnectionLoader,
        commandSender: PlantDeviceCommandSender,
        captureTimeout: TimeInterval = 10,
        schedule: @escaping Schedule
    ) {
        self.calibrationLoader = calibrationLoader
        self.rawReadingLoader = rawReadingLoader
        self.connectionLoader = connectionLoader
        self.commandSender = commandSender
        self.captureTimeout = captureTimeout
        self.schedule = schedule
    }

    public func appear() {
        loadedStatus?(PlantDeviceCalibrationStatusViewModel(calibration: calibrationLoader.load()))
        guard appeared == false else { return }
        appeared = true
        connectionLoader.subscribe { [weak self] connection in
            self?.update(connection)
        }
        rawReadingLoader.subscribe { [weak self] result in
            self?.receive(result)
        }
    }

    public func captureTap(_ point: PlantDeviceCalibrationPoint) {
        guard isConnected, capture == nil else { return }
        generation += 1
        let current = Capture(point: point, baselineSequence: latestSequence, generation: generation)
        capture = current
        loadedMessage?(nil)
        loadedCapturing?(point)
        commandSender.send(.readNow) { [weak self] error in
            guard error != nil, self?.isRunning(current) == true else { return }
            self?.finishCapture(message: String.localised(key: "plant.device.command.error"))
        }
        schedule(captureTimeout) { [weak self] in
            guard self?.isRunning(current) == true else { return false }
            self?.finishCapture(message: String.localised(key: "plant.device.calibration.error.timeout"))
            return false
        }
    }

    public func saveTap() {
        switch PlantDeviceCalibrationValidator.validate(dry: dryDraft, wet: wetDraft) {
        case .failure(let error):
            loadedMessage?(Self.message(for: error))
        case .success(let calibration):
            cancelCapture()
            calibrationLoader.save(calibration)
            loadedStatus?(PlantDeviceCalibrationStatusViewModel(calibration: calibration))
            clearDrafts()
            commandSender.send(.readNow) { _ in }
        }
    }

    public func resetTap() {
        cancelCapture()
        calibrationLoader.reset()
        loadedStatus?(PlantDeviceCalibrationStatusViewModel(calibration: calibrationLoader.load()))
        clearDrafts()
    }

    private func update(_ connection: PlantConnection) {
        let wasConnected = isConnected
        isConnected = connection == .connected
        loadedCanCapture?(isConnected)
        guard isConnected, wasConnected == false else { return }
        rawReadingLoader.load { [weak self] result in
            self?.receive(result)
        }
    }

    private func receive(_ result: PlantDeviceRawReadingLoader.Result) {
        guard case .success(let reading) = result else { return }
        defer { latestSequence = reading.sequence }
        loadedLiveSoil?(PlantDeviceFormatter.millivolts(reading.soilMillivolts))
        guard let current = capture, reading.sequence != current.baselineSequence else { return }
        guard let soil = reading.soilMillivolts else {
            finishCapture(message: String.localised(key: "plant.device.calibration.error.soil"))
            return
        }
        finishCapture(message: nil)
        setDraft(soil, for: current.point)
    }

    private func isRunning(_ candidate: Capture) -> Bool {
        capture?.generation == candidate.generation
    }

    private func finishCapture(message: String?) {
        capture = nil
        loadedCapturing?(nil)
        loadedMessage?(message)
    }

    private func cancelCapture() {
        guard capture != nil else { return }
        capture = nil
        loadedCapturing?(nil)
    }

    private func setDraft(_ soil: Int, for point: PlantDeviceCalibrationPoint) {
        switch point {
        case .dry: dryDraft = soil
        case .wet: wetDraft = soil
        }
        loadedDraft?((point, PlantDeviceFormatter.millivolts(soil)))
        loadedCanSave?(dryDraft != nil && wetDraft != nil)
        loadedWarning?(warning())
    }

    private func clearDrafts() {
        dryDraft = nil
        wetDraft = nil
        loadedDraft?((.dry, nil))
        loadedDraft?((.wet, nil))
        loadedCanSave?(false)
        loadedMessage?(nil)
        loadedWarning?(nil)
    }

    private func warning() -> String? {
        guard let dryDraft, PlantDeviceCalibrationValidator.isNearADCLimit(dry: dryDraft) else { return nil }
        return String.localised(key: "plant.device.calibration.warning.nearLimit")
    }

    private static func message(for error: PlantDeviceCalibrationError) -> String {
        switch error {
        case .missingDry: String.localised(key: "plant.device.calibration.error.missingDry")
        case .missingWet: String.localised(key: "plant.device.calibration.error.missingWet")
        case .wetNotBelowDry: String.localised(key: "plant.device.calibration.error.wetNotBelowDry")
        case .rangeTooSmall: String.localised(key: "plant.device.calibration.error.rangeTooSmall")
        }
    }
}
