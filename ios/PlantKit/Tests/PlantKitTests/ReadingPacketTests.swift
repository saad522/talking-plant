import Foundation
import Testing
import PlantKit

struct ReadingPacketTests {
    /// Fixture from docs/BLE_CONTRACT.md.
    static let fixture: [UInt8] = [
        0x01, 0x07, 0xC4, 0x09, 0xE8, 0x03, 0x2E, 0x09,
        0x90, 0x15, 0x00, 0x00, 0x2A, 0x00, 0x00, 0x00,
    ]

    static func packet(flags: UInt8 = 0x0F, temperature: [UInt8] = [0x2E, 0x09], patch: (Int, [UInt8])? = nil) -> Data {
        var bytes = fixture
        bytes[1] = flags
        bytes[6] = temperature[0]
        bytes[7] = temperature[1]
        if let (offset, values) = patch {
            bytes.replaceSubrange(offset..<offset + values.count, with: values)
        }
        return Data(bytes)
    }

    @Test func decodesFixture() throws {
        let packet = try ReadingPacket(data: Data(Self.fixture))
        #expect(packet.version == 1)
        #expect(packet.flags == [.soilValid, .lightValid, .envValid])
        #expect(packet.soilMillivolts == 2500)
        #expect(packet.lux == 1000)
        #expect(packet.temperatureCenti == 2350)
        #expect(packet.humidityCenti == 5520)
        #expect(packet.batteryMillivolts == 0)
        #expect(packet.sequence == 42)
    }

    @Test func fixtureToSensorReading() throws {
        let date = Date(timeIntervalSince1970: 1_000)
        let reading = SensorReading(packet: try ReadingPacket(data: Data(Self.fixture)), receivedAt: date)
        #expect(reading.receivedAt == date)
        #expect(reading.sequence == 42)
        #expect(reading.soilMillivolts == 2500)
        #expect(reading.lux == 1000)
        #expect(reading.temperatureCelsius == 23.5)
        #expect(reading.humidityPercent == 55.2)
        #expect(reading.batteryMillivolts == nil)
    }

    @Test func decodesDataSlice() throws {
        let padded = Data([0xFF, 0xFF] + Self.fixture + [0xFF])
        let slice = padded[2..<18]
        #expect(slice.startIndex == 2)
        #expect(try ReadingPacket(data: slice) == ReadingPacket(data: Data(Self.fixture)))
    }

    @Test(arguments: [0, 1, 15, 17, 32])
    func rejectsWrongLength(length: Int) {
        let bytes = Array((Self.fixture + Self.fixture).prefix(length))
        #expect(throws: PlantContractError.wrongLength(expected: 16, actual: length)) {
            try ReadingPacket(data: Data(bytes))
        }
    }

    @Test(arguments: [UInt8(0), 2, 0xFF])
    func rejectsWrongVersion(version: UInt8) {
        var bytes = Self.fixture
        bytes[0] = version
        #expect(throws: PlantContractError.unsupportedVersion(version)) {
            try ReadingPacket(data: Data(bytes))
        }
    }

    @Test func noFlagsMeansNoValues() throws {
        let reading = SensorReading(packet: try ReadingPacket(data: Self.packet(flags: 0)), receivedAt: .now)
        #expect(reading.soilMillivolts == nil)
        #expect(reading.lux == nil)
        #expect(reading.temperatureCelsius == nil)
        #expect(reading.humidityPercent == nil)
        #expect(reading.batteryMillivolts == nil)
        #expect(reading.sequence == 42)
    }

    @Test func eachFlagGatesItsOwnFields() throws {
        let battery = Self.packet(flags: 0b1000, patch: (10, [0x68, 0x10]))  // 4200 mV
        let soil = SensorReading(packet: try ReadingPacket(data: Self.packet(flags: 0b0001)), receivedAt: .now)
        let light = SensorReading(packet: try ReadingPacket(data: Self.packet(flags: 0b0010)), receivedAt: .now)
        let env = SensorReading(packet: try ReadingPacket(data: Self.packet(flags: 0b0100)), receivedAt: .now)
        let batt = SensorReading(packet: try ReadingPacket(data: battery), receivedAt: .now)

        #expect(soil.soilMillivolts == 2500)
        #expect(soil.lux == nil && soil.temperatureCelsius == nil && soil.batteryMillivolts == nil)

        #expect(light.lux == 1000)
        #expect(light.soilMillivolts == nil && light.humidityPercent == nil)

        #expect(env.temperatureCelsius == 23.5)
        #expect(env.humidityPercent == 55.2)
        #expect(env.soilMillivolts == nil && env.lux == nil)

        #expect(batt.batteryMillivolts == 4200)
        #expect(batt.soilMillivolts == nil && batt.lux == nil && batt.temperatureCelsius == nil)
    }

    @Test func ignoresReservedFlagBits() throws {
        let packet = try ReadingPacket(data: Self.packet(flags: 0xF7))
        #expect(packet.flags.contains([.soilValid, .lightValid, .envValid]))
        #expect(!packet.flags.contains(.batteryValid))
        let reading = SensorReading(packet: packet, receivedAt: .now)
        #expect(reading.soilMillivolts == 2500)
        #expect(reading.batteryMillivolts == nil)
    }

    @Test(arguments: [
        ([UInt8(0xE6), 0xFB], -10.5),   // -1050
        ([0xFF, 0xFF], -0.01),          // -1
        ([0x00, 0x80], -327.68),        // Int16.min
        ([0xFF, 0x7F], 327.67),         // Int16.max
        ([0x00, 0x00], 0.0),
    ])
    func decodesSignedTemperature(bytes: [UInt8], celsius: Double) throws {
        let reading = SensorReading(packet: try ReadingPacket(data: Self.packet(temperature: bytes)), receivedAt: .now)
        #expect(reading.temperatureCelsius == celsius)
    }

    @Test func decodesMaxValues() throws {
        let bytes: [UInt8] = [0x01, 0x0F] + Array(repeating: 0xFF, count: 4) + [0xFF, 0x7F] + Array(repeating: 0xFF, count: 8)
        let packet = try ReadingPacket(data: Data(bytes))
        #expect(packet.soilMillivolts == UInt16.max)
        #expect(packet.lux == UInt16.max)
        #expect(packet.temperatureCenti == Int16.max)
        #expect(packet.humidityCenti == UInt16.max)
        #expect(packet.batteryMillivolts == UInt16.max)
        #expect(packet.sequence == UInt32.max)

        let reading = SensorReading(packet: packet, receivedAt: .now)
        #expect(reading.soilMillivolts == 65535)
        #expect(reading.lux == 65535)
        #expect(reading.humidityPercent == 655.35)
        #expect(reading.batteryMillivolts == 65535)
        #expect(reading.sequence == 4_294_967_295)
    }

    @Test func decodesSequenceByteOrder() throws {
        let packet = try ReadingPacket(data: Self.packet(patch: (12, [0x04, 0x03, 0x02, 0x01])))
        #expect(packet.sequence == 0x0102_0304)
    }
}
