#if DEBUG
import PlantTestPeripheral
import XCTest

@MainActor
class PlantTestPeripheralXCTestCase: XCTestCase {
    func makeSUT(intervalSeconds: UInt16 = 30) -> PlantTestPeripheralResponder {
        PlantTestPeripheralResponder(intervalSeconds: intervalSeconds)
    }
}
#endif
