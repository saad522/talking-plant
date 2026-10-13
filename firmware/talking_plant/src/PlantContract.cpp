#include "PlantContract.h"

#include <string.h>

namespace plant {

void makeLocalName(const uint8_t addressLE[6], char out[kLocalNameSize]) {
    static const char hex[] = "0123456789ABCDEF";
    const size_t prefixLength = strlen(kLocalNamePrefix);
    memcpy(out, kLocalNamePrefix, prefixLength);
    out[prefixLength + 0] = hex[addressLE[1] >> 4];
    out[prefixLength + 1] = hex[addressLE[1] & 0x0F];
    out[prefixLength + 2] = hex[addressLE[0] >> 4];
    out[prefixLength + 3] = hex[addressLE[0] & 0x0F];
    out[prefixLength + 4] = '\0';
}

}  // namespace plant
