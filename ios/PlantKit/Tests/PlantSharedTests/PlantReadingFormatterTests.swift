import PlantShared
import XCTest

@MainActor
final class PlantReadingFormatterTests: PlantSharedXCTestCase {
    func test_percent_roundsToWholeNumber() {
        XCTAssertEqual(PlantReadingFormatter.percent(0), "0%")
        XCTAssertEqual(PlantReadingFormatter.percent(42.4), "42%")
        XCTAssertEqual(PlantReadingFormatter.percent(55.6), "56%")
        XCTAssertEqual(PlantReadingFormatter.percent(100), "100%")
    }

    func test_lux_usesGroupingSeparator() {
        XCTAssertEqual(PlantReadingFormatter.lux(0), "0 lx")
        XCTAssertEqual(PlantReadingFormatter.lux(950), "950 lx")
        XCTAssertEqual(PlantReadingFormatter.lux(65_535), "65,535 lx")
    }

    func test_temperature_usesOneDecimal() {
        XCTAssertEqual(PlantReadingFormatter.temperature(23.5), "23.5 °C")
        XCTAssertEqual(PlantReadingFormatter.temperature(21), "21.0 °C")
        XCTAssertEqual(PlantReadingFormatter.temperature(-10.5), "-10.5 °C")
    }

    func test_formatters_deliverPlaceholderOnNil() {
        XCTAssertEqual(PlantReadingFormatter.percent(nil), "–")
        XCTAssertEqual(PlantReadingFormatter.lux(nil), "–")
        XCTAssertEqual(PlantReadingFormatter.temperature(nil), "–")
    }
}
