import PlantShared
import XCTest
@testable import PlantHistory

@MainActor
final class PlantHistoryDownsamplerTests: PlantHistoryXCTestCase {
    private let tenMinutes: TimeInterval = 600

    func test_downsample_deliversNoSamplesForNoReadings() {
        XCTAssertEqual(PlantHistoryDownsampler.downsample([], bucket: tenMinutes), [])
    }

    func test_downsample_deliversOneSampleAtBucketStartForOneReading() {
        let reading = makeReading(moisture: 40, lux: 900, temperature: 21, humidity: 50, receivedAt: anyDate().addingTimeInterval(125))

        let samples = PlantHistoryDownsampler.downsample([reading], bucket: tenMinutes)

        XCTAssertEqual(samples, [makeSample(date: anyDate(), moisture: 40, lux: 900, temperature: 21, humidity: 50)])
    }

    func test_downsample_averagesEachValueWithinABucket() {
        let readings = [
            makeReading(moisture: 40, lux: 900, temperature: 20, humidity: 50, receivedAt: anyDate()),
            makeReading(moisture: 50, lux: 1_000, temperature: 22, humidity: 54, receivedAt: anyDate().addingTimeInterval(300)),
            makeReading(moisture: 60, lux: 1_100, temperature: 24, humidity: 58, receivedAt: anyDate().addingTimeInterval(599)),
        ]

        let samples = PlantHistoryDownsampler.downsample(readings, bucket: tenMinutes)

        XCTAssertEqual(samples, [makeSample(date: anyDate(), moisture: 50, lux: 1_000, temperature: 22, humidity: 54)])
    }

    func test_downsample_startsANewBucketAtTheBoundary() {
        let readings = [
            makeReading(moisture: 40, receivedAt: anyDate().addingTimeInterval(599)),
            makeReading(moisture: 60, receivedAt: anyDate().addingTimeInterval(600)),
        ]

        let samples = PlantHistoryDownsampler.downsample(readings, bucket: tenMinutes)

        XCTAssertEqual(samples.map(\.date), [anyDate(), anyDate().addingTimeInterval(600)])
        XCTAssertEqual(samples.map(\.moisture), [40, 60])
    }

    func test_downsample_ignoresMissingValuesInAverages() {
        let readings = [
            makeReading(moisture: 40, lux: nil, temperature: nil, humidity: 50, receivedAt: anyDate()),
            makeReading(moisture: nil, lux: nil, temperature: nil, humidity: 60, receivedAt: anyDate().addingTimeInterval(60)),
        ]

        let samples = PlantHistoryDownsampler.downsample(readings, bucket: tenMinutes)

        XCTAssertEqual(samples, [makeSample(date: anyDate(), moisture: 40, lux: nil, temperature: nil, humidity: 55)])
    }

    func test_downsample_deliversSamplesOldestFirstForUnsortedReadings() {
        let readings = [
            makeReading(moisture: 3, receivedAt: anyDate().addingTimeInterval(1_200)),
            makeReading(moisture: 1, receivedAt: anyDate()),
            makeReading(moisture: 2, receivedAt: anyDate().addingTimeInterval(600)),
        ]

        let samples = PlantHistoryDownsampler.downsample(readings, bucket: tenMinutes)

        XCTAssertEqual(samples.map(\.moisture), [1, 2, 3])
    }

    func test_downsample_leavesOutEmptyBuckets() {
        let readings = [
            makeReading(receivedAt: anyDate()),
            makeReading(receivedAt: anyDate().addingTimeInterval(3 * 600)),
        ]

        let samples = PlantHistoryDownsampler.downsample(readings, bucket: tenMinutes)

        XCTAssertEqual(samples.map(\.date), [anyDate(), anyDate().addingTimeInterval(1_800)])
    }

    func test_downsample_usesHourlyBucketsForAWeek() {
        let readings = (0..<6).map { index in
            makeReading(moisture: Double(index * 10), receivedAt: anyDate().addingTimeInterval(Double(index) * 20 * 60))
        }

        let samples = PlantHistoryDownsampler.downsample(readings, bucket: PlantHistoryRange.week.bucket)

        XCTAssertEqual(samples.map(\.date), [anyDate(), anyDate().addingTimeInterval(3_600)])
        XCTAssertEqual(samples.map(\.moisture), [10, 40])
    }

    func test_ranges_haveExpectedDurationsAndBuckets() {
        XCTAssertEqual(PlantHistoryRange.day.duration, 24 * 3_600)
        XCTAssertEqual(PlantHistoryRange.day.bucket, 10 * 60)
        XCTAssertEqual(PlantHistoryRange.week.duration, 7 * 24 * 3_600)
        XCTAssertEqual(PlantHistoryRange.week.bucket, 3_600)
    }
}
