#pragma once

#include <stddef.h>
#include <stdint.h>

#include "PlantContract.h"

namespace plant {

struct FirmwareVersion {
    uint8_t major, minor, patch;
};

// Protocol version 1, firmware version, capabilities 0 (V1), reserved 0, interval little-endian.
void encodeDeviceInfo(FirmwareVersion version, uint16_t intervalSeconds,
                      uint8_t out[kDeviceInfoLength]);

}  // namespace plant
