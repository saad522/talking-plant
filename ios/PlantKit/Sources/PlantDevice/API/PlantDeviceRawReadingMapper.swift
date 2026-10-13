import Foundation
import PlantShared

enum PlantDeviceRawReadingMapper {
    static func map(_ data: Data, receivedAt: Date) throws -> PlantDeviceRawReading {
        guard let packet = PlantReadingPacket(data: data),
              packet.version == PlantBluetoothContract.protocolVersion else {
            throw PeripheralPlantDeviceRawReadingLoader.Error.invalidData
        }

        return PlantDeviceRawReading(
            soilMillivolts: packet.has(.soil) ? Int(packet.soilMillivolts) : nil,
            lux: packet.has(.light) ? Int(packet.lux) : nil,
            temperature: packet.has(.environment) ? Double(packet.temperatureCenti) / 100 : nil,
            humidity: packet.has(.environment) ? Double(packet.humidityCenti) / 100 : nil,
            flags: packet.flags,
            sequence: packet.sequence,
            receivedAt: receivedAt
        )
    }
}
