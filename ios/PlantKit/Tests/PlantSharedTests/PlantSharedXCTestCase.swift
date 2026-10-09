import PlantShared
import XCTest

@MainActor
class PlantSharedXCTestCase: XCTestCase {
    func makeCalibration(dry: Int, wet: Int, file: StaticString = #filePath, line: UInt = #line) throws -> MoistureCalibration {
        try XCTUnwrap(MoistureCalibration(dryMillivolts: dry, wetMillivolts: wet), file: file, line: line)
    }
}
