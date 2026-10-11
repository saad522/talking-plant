import Foundation
import PlantShared

enum PlantReadingMapper {
    private struct RemoteReading {
        private enum Flag: UInt8 {
            case soil = 0b0001
            case light = 0b0010
            case environment = 0b0100
            case battery = 0b1000
        }

        let version: UInt8
        private let flags: UInt8
        private let soilMillivolts: UInt16
        private let lux: UInt16
        private let temperatureCenti: Int16
        private let humidityCenti: UInt16
        private let batteryMillivolts: UInt16
        private let sequence: UInt32

        init?(data: Data) {
            guard data.count == PlantBluetoothContract.readingLength else { return nil }
            let bytes = [UInt8](data)
            version = bytes[0]
            flags = bytes[1]
            soilMillivolts = bytes.uint16(at: 2)
            lux = bytes.uint16(at: 4)
            temperatureCenti = Int16(bitPattern: bytes.uint16(at: 6))
            humidityCenti = bytes.uint16(at: 8)
            batteryMillivolts = bytes.uint16(at: 10)
            sequence = bytes.uint32(at: 12)
        }

        func local(receivedAt: Date, calibration: MoistureCalibration) -> PlantReading {
            PlantReading(
                moisture: has(.soil) ? calibration.moisturePercent(soilMillivolts: Int(soilMillivolts)) : nil,
                lux: has(.light) ? Int(lux) : nil,
                temperature: has(.environment) ? Double(temperatureCenti) / 100 : nil,
                humidity: has(.environment) ? Double(humidityCenti) / 100 : nil,
                batteryMillivolts: has(.battery) ? Int(batteryMillivolts) : nil,
                sequence: sequence,
                receivedAt: receivedAt
            )
        }

        private func has(_ flag: Flag) -> Bool {
            flags & flag.rawValue != 0
        }
    }

    static func map(_ data: Data, receivedAt: Date, calibration: MoistureCalibration) throws -> PlantReading {
        guard let reading = RemoteReading(data: data),
              reading.version == PlantBluetoothContract.protocolVersion else {
            throw PeripheralPlantReadingLoader.Error.invalidData
        }

        return reading.local(receivedAt: receivedAt, calibration: calibration)
    }
}

private extension Array where Element == UInt8 {
    func uint16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func uint32(at offset: Int) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { value, index in
            value | UInt32(self[offset + index]) << (8 * index)
        }
    }
}
