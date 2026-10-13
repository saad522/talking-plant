import Foundation
import PlantShared

enum PlantReadingMapper {
    static func map(_ data: Data, receivedAt: Date, calibration: MoistureCalibration) throws -> PlantReading {
        guard let packet = PlantReadingPacket(data: data),
              packet.version == PlantBluetoothContract.protocolVersion else {
            throw PeripheralPlantReadingLoader.Error.invalidData
        }

        return PlantReading(
            moisture: packet.has(.soil) ? calibration.moisturePercent(soilMillivolts: Int(packet.soilMillivolts)) : nil,
            lux: packet.has(.light) ? Int(packet.lux) : nil,
            temperature: packet.has(.environment) ? Double(packet.temperatureCenti) / 100 : nil,
            humidity: packet.has(.environment) ? Double(packet.humidityCenti) / 100 : nil,
            batteryMillivolts: packet.has(.battery) ? Int(packet.batteryMillivolts) : nil,
            sequence: packet.sequence,
            receivedAt: receivedAt
        )
    }
}
