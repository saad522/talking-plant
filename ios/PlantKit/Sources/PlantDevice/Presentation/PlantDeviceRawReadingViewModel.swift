import PlantShared

public struct PlantDeviceRawReadingViewModel: Equatable {
    public let soil: String
    public let light: String
    public let temperature: String
    public let humidity: String
    public let flags: String
    public let sequence: String
    public let received: String

    public init(reading: PlantDeviceRawReading) {
        soil = PlantDeviceFormatter.millivolts(reading.soilMillivolts)
        light = PlantReadingFormatter.lux(reading.lux)
        temperature = PlantDeviceFormatter.decimal(reading.temperature, unit: "°C")
        humidity = PlantDeviceFormatter.decimal(reading.humidity, unit: "%")
        flags = PlantDeviceFormatter.flags(reading.flags)
        sequence = "#\(reading.sequence)"
        received = PlantDeviceFormatter.time(reading.receivedAt)
    }
}
