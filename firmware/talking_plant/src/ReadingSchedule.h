#pragma once

#include <stdint.h>

namespace plant {

class ReadingSchedule {
public:
    explicit ReadingSchedule(uint16_t intervalSeconds);  // clamps 10-3600
    uint16_t intervalSeconds() const { return intervalSeconds_; }
    void setIntervalSeconds(uint16_t seconds);  // clamps 10-3600
    bool isDue(uint32_t nowMs) const;           // true before the first reading
    void markTaken(uint32_t nowMs);

private:
    uint16_t intervalSeconds_;
    uint32_t lastMs_ = 0;
    bool hasTaken_ = false;
};

}  // namespace plant
