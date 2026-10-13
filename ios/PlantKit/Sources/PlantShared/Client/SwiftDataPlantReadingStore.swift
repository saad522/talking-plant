import Foundation
import SwiftData

/// SwiftData-backed history. Keeps `retention` worth of readings, measured back from the
/// newest inserted reading (not the wall clock), so it also works with the simulated clock.
@MainActor
public final class SwiftDataPlantReadingStore: PlantReadingStore {
    public static let defaultRetention: TimeInterval = 30 * 24 * 3_600

    private let container: ModelContainer
    private let context: ModelContext
    private let retention: TimeInterval
    private var subscriptions: [() -> Void] = []

    /// - Parameter storeURL: File for the store. `nil` keeps it in memory.
    public init(storeURL: URL?, retention: TimeInterval = defaultRetention) throws {
        let configuration = if let storeURL {
            ModelConfiguration(url: storeURL)
        } else {
            ModelConfiguration(UUID().uuidString, isStoredInMemoryOnly: true)
        }
        container = try ModelContainer(for: LocalPlantReading.self, configurations: configuration)
        context = ModelContext(container)
        self.retention = retention
    }

    public func insert(_ reading: PlantReading, completion: @escaping (InsertionResult) -> Void) {
        do {
            context.insert(LocalPlantReading(reading))
            let cutoff = reading.receivedAt.addingTimeInterval(-retention)
            try context.delete(model: LocalPlantReading.self, where: #Predicate { $0.receivedAt < cutoff })
            try context.save()
        } catch {
            context.rollback()
            return completion(error)
        }

        completion(nil)
        subscriptions.forEach { $0() }
    }

    public func retrieve(from start: Date, to end: Date, completion: @escaping (RetrievalResult) -> Void) {
        let descriptor = FetchDescriptor<LocalPlantReading>(
            predicate: #Predicate { $0.receivedAt >= start && $0.receivedAt <= end },
            sortBy: [SortDescriptor(\.receivedAt), SortDescriptor(\.sequence)]
        )

        completion(RetrievalResult(catching: {
            try context.fetch(descriptor).map(\.local)
        }))
    }

    public func deleteAll(completion: @escaping (DeletionResult) -> Void) {
        do {
            try context.delete(model: LocalPlantReading.self)
            try context.save()
        } catch {
            context.rollback()
            return completion(error)
        }

        completion(nil)
        subscriptions.forEach { $0() }
    }

    public func subscribe(update: @escaping () -> Void) {
        subscriptions.append(update)
    }
}

@Model
private final class LocalPlantReading {
    #Index<LocalPlantReading>([\.receivedAt])

    var moisture: Double?
    var lux: Int?
    var temperature: Double?
    var humidity: Double?
    var batteryMillivolts: Int?
    var sequence: Int
    var receivedAt: Date

    init(_ reading: PlantReading) {
        moisture = reading.moisture
        lux = reading.lux
        temperature = reading.temperature
        humidity = reading.humidity
        batteryMillivolts = reading.batteryMillivolts
        sequence = Int(reading.sequence)
        receivedAt = reading.receivedAt
    }

    var local: PlantReading {
        PlantReading(
            moisture: moisture,
            lux: lux,
            temperature: temperature,
            humidity: humidity,
            batteryMillivolts: batteryMillivolts,
            sequence: UInt32(sequence),
            receivedAt: receivedAt
        )
    }
}
