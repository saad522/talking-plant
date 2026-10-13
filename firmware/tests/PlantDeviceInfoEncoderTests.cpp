#include "PlantDeviceInfoEncoder.h"
#include "check.h"

TEST(test_encodeDeviceInfo_matchesContractFixture) {
    uint8_t packet[plant::kDeviceInfoLength];
    const uint8_t expected[] = {0x01, 0x01, 0x02, 0x03, 0x00, 0x00, 0x2C, 0x01};

    plant::encodeDeviceInfo({1, 2, 3}, 300, packet);

    CHECK_BYTES(packet, expected, sizeof(expected));
}

TEST(test_encodeDeviceInfo_encodesMaxIntervalLittleEndian) {
    uint8_t packet[plant::kDeviceInfoLength];

    plant::encodeDeviceInfo({0, 1, 0}, 3600, packet);

    CHECK_EQ(packet[6], 0x10);
    CHECK_EQ(packet[7], 0x0E);
}

TEST(test_encodeDeviceInfo_capabilitiesAndReservedAreZero) {
    uint8_t packet[plant::kDeviceInfoLength];

    plant::encodeDeviceInfo({255, 255, 255}, 65535, packet);

    CHECK_EQ(packet[0], 1);
    CHECK_EQ(packet[4], 0);
    CHECK_EQ(packet[5], 0);
}
