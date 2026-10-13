#include "PlantCommandParser.h"

namespace plant {

namespace {

constexpr uint8_t kReadNowOpcode = 0x01;
constexpr uint8_t kSetIntervalOpcode = 0x02;
constexpr uint8_t kPumpRunOpcode = 0x10;
constexpr uint8_t kPumpStopOpcode = 0x11;

uint16_t readUInt16(const uint8_t* in) {
    return static_cast<uint16_t>(in[0] | (in[1] << 8));
}

}  // namespace

Command parseCommand(const uint8_t* data, size_t length) {
    const Command ignored{CommandType::Ignored, 0};
    if (data == nullptr || length == 0) return ignored;

    switch (data[0]) {
        case kReadNowOpcode:
            return Command{CommandType::ReadNow, 0};
        case kSetIntervalOpcode: {
            if (length < 3) return ignored;
            uint16_t seconds = readUInt16(data + 1);
            if (seconds < kMinIntervalSeconds) seconds = kMinIntervalSeconds;
            if (seconds > kMaxIntervalSeconds) seconds = kMaxIntervalSeconds;
            return Command{CommandType::SetInterval, seconds};
        }
        case kPumpRunOpcode: {
            if (length < 3) return ignored;
            uint16_t milliseconds = readUInt16(data + 1);
            if (milliseconds > kMaxPumpMilliseconds) milliseconds = kMaxPumpMilliseconds;
            return Command{CommandType::PumpRun, milliseconds};
        }
        case kPumpStopOpcode:
            return Command{CommandType::PumpStop, 0};
        default:
            return ignored;
    }
}

}  // namespace plant
