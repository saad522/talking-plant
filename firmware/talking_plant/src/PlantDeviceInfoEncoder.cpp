#include "PlantDeviceInfoEncoder.h"

#include <string.h>

namespace plant {

void encodeDeviceInfo(FirmwareVersion version, uint16_t intervalSeconds,
                      uint8_t out[kDeviceInfoLength]) {
    memset(out, 0, kDeviceInfoLength);
    out[0] = kProtocolVersion;
    out[1] = version.major;
    out[2] = version.minor;
    out[3] = version.patch;
    // Byte 4: capabilities, none in V1. Byte 5: reserved.
    out[6] = static_cast<uint8_t>(intervalSeconds & 0xFF);
    out[7] = static_cast<uint8_t>(intervalSeconds >> 8);
}

}  // namespace plant
