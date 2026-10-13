#include <math.h>

#include "PlantReadingEncoder.h"
#include "check.h"

namespace {

plant::SensorSample validSample() {
    return plant::SensorSample{true, 2500, true, 1000.0f, true, 23.5f, 55.2f};
}

}  // namespace

TEST(test_encodeReading_matchesContractFixture) {
    uint8_t packet[plant::kReadingLength];
    const uint8_t expected[] = {0x01, 0x07, 0xC4, 0x09, 0xE8, 0x03, 0x2E, 0x09,
                                0x90, 0x15, 0x00, 0x00, 0x2A, 0x00, 0x00, 0x00};

    plant::encodeReading(validSample(), 42, packet);

    CHECK_BYTES(packet, expected, sizeof(expected));
}

TEST(test_encodeReading_soilFailingClearsOnlySoil) {
    auto sample = validSample();
    sample.soilValid = false;
    uint8_t packet[plant::kReadingLength];

    plant::encodeReading(sample, 0, packet);

    CHECK_EQ(packet[1], 0x06);
    CHECK_EQ(packet[2], 0);
    CHECK_EQ(packet[3], 0);
}

TEST(test_encodeReading_lightFailingClearsOnlyLight) {
    uint8_t packet[plant::kReadingLength];
    auto invalid = validSample();
    invalid.lightValid = false;
    auto negative = validSample();
    negative.lux = -2;
    auto notANumber = validSample();
    notANumber.lux = NAN;

    const plant::SensorSample samples[] = {invalid, negative, notANumber};
    for (const auto& sample : samples) {
        plant::encodeReading(sample, 0, packet);
        CHECK_EQ(packet[1], 0x05);
        CHECK_EQ(packet[4], 0);
        CHECK_EQ(packet[5], 0);
    }
}

TEST(test_encodeReading_envFailingClearsOnlyEnv) {
    uint8_t packet[plant::kReadingLength];
    auto invalid = validSample();
    invalid.envValid = false;
    auto badTemperature = validSample();
    badTemperature.temperatureC = NAN;
    auto badHumidity = validSample();
    badHumidity.humidityPercent = NAN;

    const plant::SensorSample samples[] = {invalid, badTemperature, badHumidity};
    for (const auto& sample : samples) {
        plant::encodeReading(sample, 0, packet);
        CHECK_EQ(packet[1], 0x03);
        for (int i = 6; i <= 9; i++) CHECK_EQ(packet[i], 0);
    }
}

TEST(test_encodeReading_allFailingSendsOnlyVersionAndSequence) {
    plant::SensorSample sample{false, 2500, false, 1000.0f, false, 23.5f, 55.2f};
    uint8_t packet[plant::kReadingLength];
    const uint8_t expected[] = {0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                0x00, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00};

    plant::encodeReading(sample, 7, packet);

    CHECK_BYTES(packet, expected, sizeof(expected));
}

TEST(test_encodeReading_batteryBytesAndHighFlagsAreAlwaysZero) {
    uint8_t packet[plant::kReadingLength];

    plant::encodeReading(validSample(), 1, packet);

    CHECK_EQ(packet[10], 0);
    CHECK_EQ(packet[11], 0);
    CHECK_EQ(packet[1] & plant::kBatteryValid, 0);
    CHECK_EQ(packet[1] & 0xF0, 0);
}

TEST(test_encodeReading_writesMultiByteFieldsLittleEndian) {
    auto sample = validSample();
    sample.soilMillivolts = 0x1234;
    uint8_t packet[plant::kReadingLength];

    plant::encodeReading(sample, 0x01020304, packet);

    CHECK_EQ(packet[2], 0x34);
    CHECK_EQ(packet[3], 0x12);
    const uint8_t sequence[] = {0x04, 0x03, 0x02, 0x01};
    CHECK_BYTES(packet + 12, sequence, 4);

    plant::encodeReading(sample, 0xFFFFFFFF, packet);
    const uint8_t maxSequence[] = {0xFF, 0xFF, 0xFF, 0xFF};
    CHECK_BYTES(packet + 12, maxSequence, 4);
}

TEST(test_encodeReading_encodesSignedTemperature) {
    auto sample = validSample();
    uint8_t packet[plant::kReadingLength];

    sample.temperatureC = -10.5f;
    plant::encodeReading(sample, 0, packet);
    CHECK_EQ(packet[6], 0xE6);
    CHECK_EQ(packet[7], 0xFB);

    sample.temperatureC = -0.01f;
    plant::encodeReading(sample, 0, packet);
    CHECK_EQ(packet[6], 0xFF);
    CHECK_EQ(packet[7], 0xFF);
}

TEST(test_encodeReading_clampsLux) {
    auto sample = validSample();
    uint8_t packet[plant::kReadingLength];

    sample.lux = 70000;
    plant::encodeReading(sample, 0, packet);
    CHECK_EQ(packet[4], 0xFF);
    CHECK_EQ(packet[5], 0xFF);

    sample.lux = 0.4f;
    plant::encodeReading(sample, 0, packet);
    CHECK_EQ(packet[4], 0x00);
    CHECK_EQ(packet[5], 0x00);

    sample.lux = 0.6f;
    plant::encodeReading(sample, 0, packet);
    CHECK_EQ(packet[4], 0x01);
    CHECK_EQ(packet[5], 0x00);
}

TEST(test_encodeReading_clampsSoil) {
    auto sample = validSample();
    sample.soilMillivolts = 70000;
    uint8_t packet[plant::kReadingLength];

    plant::encodeReading(sample, 0, packet);

    CHECK_EQ(packet[2], 0xFF);
    CHECK_EQ(packet[3], 0xFF);
}

TEST(test_encodeReading_clampsTemperatureAndHumidity) {
    auto sample = validSample();
    uint8_t packet[plant::kReadingLength];

    sample.temperatureC = 400;
    plant::encodeReading(sample, 0, packet);
    CHECK_EQ(packet[6], 0xFF);
    CHECK_EQ(packet[7], 0x7F);

    sample.temperatureC = -400;
    plant::encodeReading(sample, 0, packet);
    CHECK_EQ(packet[6], 0x00);
    CHECK_EQ(packet[7], 0x80);

    sample = validSample();
    sample.humidityPercent = 700;
    plant::encodeReading(sample, 0, packet);
    CHECK_EQ(packet[8], 0xFF);
    CHECK_EQ(packet[9], 0xFF);
}

TEST(test_encodeReading_roundsInsteadOfTruncating) {
    uint8_t packet[plant::kReadingLength];

    plant::encodeReading(validSample(), 0, packet);

    CHECK_EQ(packet[8], 0x90);
    CHECK_EQ(packet[9], 0x15);
}

TEST(test_readingSequence_countsUpFromZero) {
    plant::ReadingSequence sequence;

    CHECK_EQ(sequence.take(), 0);
    CHECK_EQ(sequence.take(), 1);
    CHECK_EQ(sequence.take(), 2);
}

TEST(test_readingSequence_wrapsToZeroAfterMax) {
    plant::ReadingSequence sequence(0xFFFFFFFF);

    CHECK_EQ(sequence.take(), 0xFFFFFFFF);
    CHECK_EQ(sequence.take(), 0);
}
