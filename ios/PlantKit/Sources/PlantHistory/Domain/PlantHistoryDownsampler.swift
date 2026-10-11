import Foundation
import PlantShared

/// Groups readings into fixed-width time buckets and averages each value, ignoring `nil`s.
/// Buckets start at whole multiples of `bucket` since 1970; empty buckets are left out.
enum PlantHistoryDownsampler {
    static func downsample(_ readings: [PlantReading], bucket: TimeInterval) -> [PlantHistorySample] {
        let buckets = Dictionary(grouping: readings) { reading in
            (reading.receivedAt.timeIntervalSince1970 / bucket).rounded(.down)
        }

        return buckets.keys.sorted().map { key in
            let readings = buckets[key] ?? []
            return PlantHistorySample(
                date: Date(timeIntervalSince1970: key * bucket),
                moisture: average(readings.compactMap(\.moisture)),
                lux: average(readings.compactMap(\.lux).map(Double.init)),
                temperature: average(readings.compactMap(\.temperature)),
                humidity: average(readings.compactMap(\.humidity))
            )
        }
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
