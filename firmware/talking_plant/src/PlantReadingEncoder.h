#pragma once

#include <stddef.h>
#include <stdint.h>

#include "PlantContract.h"

namespace plant {

struct SensorSample {
    bool soilValid;
    uint32_t soilMillivolts;  // analogReadMilliVolts
    bool lightValid;
    float lux;  // BH1750 returns < 0 on error
    bool envValid;
    float temperatureC;
    float humidityPercent;
};

// 0 after boot, +1 per reading, wraps.
class ReadingSequence {
public:
    explicit ReadingSequence(uint32_t first = 0) : next_(first) {}
    uint32_t take();  // returns current, then increments

private:
    uint32_t next_;
};

void encodeReading(const SensorSample& sample, uint32_t sequence, uint8_t out[kReadingLength]);

}  // namespace plant
