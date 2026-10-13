#include "PlantReadingEncoder.h"

#include <math.h>
#include <string.h>

namespace plant {

namespace {

void writeUInt16(uint16_t value, uint8_t* out) {
    out[0] = static_cast<uint8_t>(value & 0xFF);
    out[1] = static_cast<uint8_t>(value >> 8);
}

void writeUInt32(uint32_t value, uint8_t* out) {
    out[0] = static_cast<uint8_t>(value & 0xFF);
    out[1] = static_cast<uint8_t>((value >> 8) & 0xFF);
    out[2] = static_cast<uint8_t>((value >> 16) & 0xFF);
    out[3] = static_cast<uint8_t>(value >> 24);
}

// Clamps before the cast, so an out-of-range float never reaches the integer conversion.
long roundClamped(float value, float low, float high) {
    if (value < low) value = low;
    if (value > high) value = high;
    return lroundf(value);
}

}  // namespace

uint32_t ReadingSequence::take() {
    return next_++;
}

void encodeReading(const SensorSample& sample, uint32_t sequence, uint8_t out[kReadingLength]) {
    memset(out, 0, kReadingLength);
    uint8_t flags = 0;

    out[0] = kProtocolVersion;

    if (sample.soilValid) {
        flags |= kSoilValid;
        const uint32_t mv = sample.soilMillivolts > 65535 ? 65535 : sample.soilMillivolts;
        writeUInt16(static_cast<uint16_t>(mv), out + 2);
    }

    if (sample.lightValid && !isnan(sample.lux) && sample.lux >= 0) {
        flags |= kLightValid;
        writeUInt16(static_cast<uint16_t>(roundClamped(sample.lux, 0, 65535)), out + 4);
    }

    if (sample.envValid && !isnan(sample.temperatureC) && !isnan(sample.humidityPercent)) {
        flags |= kEnvValid;
        const long temperature = roundClamped(sample.temperatureC * 100, -32768, 32767);
        const long humidity = roundClamped(sample.humidityPercent * 100, 0, 65535);
        writeUInt16(static_cast<uint16_t>(static_cast<int16_t>(temperature)), out + 6);
        writeUInt16(static_cast<uint16_t>(humidity), out + 8);
    }

    out[1] = flags;
    // Bytes 10-11: battery, not measured in V1.
    writeUInt32(sequence, out + 12);
}

}  // namespace plant
