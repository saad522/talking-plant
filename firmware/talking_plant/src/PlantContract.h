#pragma once

#include <stddef.h>
#include <stdint.h>

namespace plant {

constexpr uint8_t kProtocolVersion = 1;
constexpr size_t kReadingLength = 16;
constexpr size_t kDeviceInfoLength = 8;

constexpr const char* kServiceUUID = "7697A001-5F72-4B79-B7A4-6632379F2F13";
constexpr const char* kReadingsUUID = "7697A002-5F72-4B79-B7A4-6632379F2F13";
constexpr const char* kDeviceInfoUUID = "7697A003-5F72-4B79-B7A4-6632379F2F13";
constexpr const char* kCommandUUID = "7697A004-5F72-4B79-B7A4-6632379F2F13";

constexpr const char* kLocalNamePrefix = "TalkingPlant-";
constexpr size_t kLocalNameSize = 18;  // 13 + 4 hex + '\0'

enum ReadingFlag : uint8_t {
    kSoilValid = 1 << 0,
    kLightValid = 1 << 1,
    kEnvValid = 1 << 2,
    kBatteryValid = 1 << 3,
};

constexpr uint16_t kMinIntervalSeconds = 10;
constexpr uint16_t kMaxIntervalSeconds = 3600;
constexpr uint16_t kMaxPumpMilliseconds = 10000;

// addressLE is NimBLE's getVal() order: index 0 is the LAST byte of "AA:BB:CC:DD:EE:FF".
// Writes "TalkingPlant-EEFF" (uppercase hex).
void makeLocalName(const uint8_t addressLE[6], char out[kLocalNameSize]);

}  // namespace plant
