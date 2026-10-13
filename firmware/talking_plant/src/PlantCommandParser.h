#pragma once

#include <stddef.h>
#include <stdint.h>

#include "PlantContract.h"

namespace plant {

enum class CommandType : uint8_t { Ignored, ReadNow, SetInterval, PumpRun, PumpStop };

struct Command {
    CommandType type;
    uint16_t value;  // seconds or milliseconds, already clamped
};

Command parseCommand(const uint8_t* data, size_t length);

}  // namespace plant
