#include <Adafruit_AHTX0.h>
#include <BH1750.h>
#include <NimBLEDevice.h>
#include <Wire.h>

#include <atomic>

#include "src/PlantCommandParser.h"
#include "src/PlantContract.h"
#include "src/PlantDeviceInfoEncoder.h"
#include "src/PlantReadingEncoder.h"
#include "src/ReadingSchedule.h"

constexpr uint8_t kSoilPin = A0;
constexpr plant::FirmwareVersion kFirmwareVersion{0, 1, 0};
constexpr uint16_t kDefaultIntervalSeconds = 30;
constexpr int kSoilSamples = 8;  // averaged per reading

// Soil failure detection is off until M8 shows what an unplugged pin reads.
// When enabled, an average at or below the threshold is reported as invalid.
constexpr bool kSoilFailureCheckEnabled = false;
constexpr uint32_t kSoilFailureMillivolts = 0;

constexpr uint8_t kLightAddress = 0x23;
constexpr uint8_t kEnvAddress = 0x38;

BH1750 lightMeter(kLightAddress);
Adafruit_AHTX0 aht;
bool lightReady = false;
bool envReady = false;

plant::ReadingSchedule schedule(kDefaultIntervalSeconds);
plant::ReadingSequence sequence;

NimBLECharacteristic* readings = nullptr;
NimBLECharacteristic* deviceInfo = nullptr;

// Set from the NimBLE host task, handled in loop(). Callbacks never touch I2C or the ADC.
std::atomic<bool> readNowRequested{false};
std::atomic<uint16_t> requestedInterval{0};  // 0 = none

void publishDeviceInfo() {
  uint8_t info[plant::kDeviceInfoLength];
  plant::encodeDeviceInfo(kFirmwareVersion, schedule.intervalSeconds(), info);
  deviceInfo->setValue(info, sizeof(info));
}

class ServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer*, NimBLEConnInfo& connInfo) override {
    Serial.printf("[ble] connected %s\n", connInfo.getAddress().toString().c_str());
  }
  void onDisconnect(NimBLEServer*, NimBLEConnInfo&, int reason) override {
    Serial.printf("[ble] disconnected, reason 0x%02X, advertising\n", reason);
  }
};

class ReadingsCallbacks : public NimBLECharacteristicCallbacks {
  void onSubscribe(NimBLECharacteristic*, NimBLEConnInfo&, uint16_t subValue) override {
    Serial.printf("[ble] readings %s\n", subValue & 1 ? "subscribed" : "unsubscribed");
  }
};

class CommandCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* characteristic, NimBLEConnInfo&) override {
    const NimBLEAttValue value = characteristic->getValue();
    const plant::Command command = plant::parseCommand(value.data(), value.size());
    switch (command.type) {
      case plant::CommandType::ReadNow:
        Serial.println("[cmd] READ_NOW");
        readNowRequested = true;
        break;
      case plant::CommandType::SetInterval:
        Serial.printf("[cmd] SET_INTERVAL %u s\n", command.value);
        requestedInterval = command.value;
        break;
      case plant::CommandType::PumpRun:
        Serial.printf("[cmd] PUMP_RUN %u ms ignored, no pump\n", command.value);
        break;
      case plant::CommandType::PumpStop:
        Serial.println("[cmd] PUMP_STOP ignored, no pump");
        break;
      case plant::CommandType::Ignored:
        if (value.size() > 0) Serial.printf("[cmd] ignored %02X\n", value.data()[0]);
        else Serial.println("[cmd] ignored (empty)");
        break;
    }
  }
};

ServerCallbacks serverCallbacks;
ReadingsCallbacks readingsCallbacks;
CommandCallbacks commandCallbacks;

bool probe(uint8_t address) {
  Wire.beginTransmission(address);
  return Wire.endTransmission() == 0;
}

void takeReading() {
  plant::SensorSample sample{};

  uint32_t total = 0;
  for (int i = 0; i < kSoilSamples; i++) {
    total += analogReadMilliVolts(kSoilPin);
  }
  sample.soilMillivolts = total / kSoilSamples;
  sample.soilValid = !kSoilFailureCheckEnabled || sample.soilMillivolts > kSoilFailureMillivolts;

  if (!lightReady) {
    lightReady = lightMeter.begin();
  }
  if (lightReady) {
    sample.lux = lightMeter.readLightLevel();
    sample.lightValid = sample.lux >= 0;
  }

  if (!envReady) {
    envReady = aht.begin();
  }
  if (envReady) {
    sensors_event_t humidity, temperature;
    sample.envValid = aht.getEvent(&humidity, &temperature);
    if (sample.envValid) {
      sample.temperatureC = temperature.temperature;
      sample.humidityPercent = humidity.relative_humidity;
    }
  }

  const uint32_t number = sequence.take();
  uint8_t packet[plant::kReadingLength];
  plant::encodeReading(sample, number, packet);
  readings->setValue(packet, sizeof(packet));  // before notify, so a read returns the latest
  readings->notify();

  Serial.printf("[read] #%lu soil ", static_cast<unsigned long>(number));
  if (sample.soilValid) Serial.printf("%lu mV", static_cast<unsigned long>(sample.soilMillivolts));
  else Serial.print("--");
  Serial.print(", lux ");
  if (sample.lightValid) Serial.printf("%.0f", sample.lux);
  else Serial.print("--");
  Serial.print(", env ");
  if (sample.envValid) Serial.printf("%.2f C %.2f %%", sample.temperatureC, sample.humidityPercent);
  else Serial.print("--");
  Serial.printf(", flags 0x%02X |", packet[1]);
  for (size_t i = 0; i < plant::kReadingLength; i++) {
    Serial.printf(" %02X", packet[i]);
  }
  Serial.println();

  schedule.markTaken(millis());
}

void setup() {
  Serial.begin(115200);
  while (!Serial && millis() < 2000) {
  }

  analogSetPinAttenuation(kSoilPin, ADC_11db);

  Wire.begin();
  Serial.printf("[i2c] 0x%02X BH1750 %s, 0x%02X AHT20 %s\n", kLightAddress,
                probe(kLightAddress) ? "ok" : "missing", kEnvAddress,
                probe(kEnvAddress) ? "ok" : "missing");
  Serial.print("[i2c] found:");
  bool anyFound = false;
  for (uint8_t address = 0x08; address <= 0x77; address++) {
    if (probe(address)) {
      Serial.printf(" 0x%02X", address);
      anyFound = true;
    }
  }
  Serial.println(anyFound ? "" : " none");

  lightReady = lightMeter.begin();
  envReady = aht.begin();
  delay(200);  // the BH1750's first measurement needs to exist

  NimBLEDevice::init("");
  char name[plant::kLocalNameSize];
  plant::makeLocalName(NimBLEDevice::getAddress().getVal(), name);
  NimBLEDevice::setDeviceName(name);  // GAP name matches the advertised one

  NimBLEServer* server = NimBLEDevice::createServer();
  server->setCallbacks(&serverCallbacks);
  server->advertiseOnDisconnect(true);

  NimBLEService* service = server->createService(plant::kServiceUUID);
  readings = service->createCharacteristic(plant::kReadingsUUID,
                                           NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  readings->setCallbacks(&readingsCallbacks);
  deviceInfo = service->createCharacteristic(plant::kDeviceInfoUUID, NIMBLE_PROPERTY::READ);
  NimBLECharacteristic* command =
      service->createCharacteristic(plant::kCommandUUID, NIMBLE_PROPERTY::WRITE);
  command->setCallbacks(&commandCallbacks);
  publishDeviceInfo();
  service->start();

  takeReading();  // sequence 0, so a read never returns an empty value

  // Scan response first: the name goes there because flags + UUID + name exceed 31 bytes.
  NimBLEAdvertising* advertising = NimBLEDevice::getAdvertising();
  advertising->enableScanResponse(true);
  advertising->setName(name);
  advertising->addServiceUUID(plant::kServiceUUID);
  advertising->start();

  Serial.printf("[boot] %s fw %u.%u.%u addr %s interval %u s\n", name, kFirmwareVersion.major,
                kFirmwareVersion.minor, kFirmwareVersion.patch,
                NimBLEDevice::getAddress().toString().c_str(), schedule.intervalSeconds());
}

void loop() {
  const uint16_t interval = requestedInterval.exchange(0);
  if (interval != 0) {
    const uint16_t previous = schedule.intervalSeconds();
    schedule.setIntervalSeconds(interval);
    publishDeviceInfo();
    Serial.printf("[cmd] interval %u s -> %u s\n", previous, schedule.intervalSeconds());
  }
  if (readNowRequested.exchange(false) || schedule.isDue(millis())) {
    takeReading();
  }
  delay(10);
}
