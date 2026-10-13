#include <Adafruit_AHTX0.h>
#include <BH1750.h>
#include <Wire.h>

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

  lightReady = lightMeter.begin();
  envReady = aht.begin();
  delay(200);  // the BH1750's first measurement needs to exist

  Serial.printf("[boot] talking_plant fw %u.%u.%u interval %u s\n", kFirmwareVersion.major,
                kFirmwareVersion.minor, kFirmwareVersion.patch, schedule.intervalSeconds());
}

void loop() {
  if (schedule.isDue(millis())) {
    takeReading();
  }
  delay(10);
}
