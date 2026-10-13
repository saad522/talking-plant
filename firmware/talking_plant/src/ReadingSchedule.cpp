#include "ReadingSchedule.h"

#include "PlantContract.h"

namespace plant {

namespace {

uint16_t clampInterval(uint16_t seconds) {
    if (seconds < kMinIntervalSeconds) return kMinIntervalSeconds;
    if (seconds > kMaxIntervalSeconds) return kMaxIntervalSeconds;
    return seconds;
}

}  // namespace

ReadingSchedule::ReadingSchedule(uint16_t intervalSeconds)
    : intervalSeconds_(clampInterval(intervalSeconds)) {}

void ReadingSchedule::setIntervalSeconds(uint16_t seconds) {
    intervalSeconds_ = clampInterval(seconds);
}

bool ReadingSchedule::isDue(uint32_t nowMs) const {
    if (!hasTaken_) return true;
    // Unsigned subtraction handles the millis() wraparound.
    return nowMs - lastMs_ >= static_cast<uint32_t>(intervalSeconds_) * 1000u;
}

void ReadingSchedule::markTaken(uint32_t nowMs) {
    lastMs_ = nowMs;
    hasTaken_ = true;
}

}  // namespace plant
