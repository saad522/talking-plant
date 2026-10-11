import PlantMonitor
import XCTest

extension PlantMonitorXCTestCase {
    func expect(
        reading sut: PlantReadingLoader,
        toDeliver expectedResult: PlantReadingLoader.Result,
        when action: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let exp = expectation(description: "wait for reading")

        sut.subscribe { result in
            switch (expectedResult, result) {
            case let (.success(expected), .success(received)):
                XCTAssertEqual(expected, received, file: file, line: line)
            case let (.failure(expected as PeripheralPlantReadingLoader.Error), .failure(received as PeripheralPlantReadingLoader.Error)):
                XCTAssertEqual(expected, received, file: file, line: line)
            case let (.failure(expected as NSError), .failure(received as NSError)):
                XCTAssertEqual(expected, received, file: file, line: line)
            default:
                XCTFail("Expected \(expectedResult), got \(result) instead", file: file, line: line)
            }

            exp.fulfill()
        }

        action()

        wait(for: [exp], timeout: 1.0)
    }
}
