#include <string.h>

#include "PlantContract.h"
#include "check.h"

TEST(test_contract_uuidsMatchContractText) {
    CHECK(strcmp(plant::kServiceUUID, "7697A001-5F72-4B79-B7A4-6632379F2F13") == 0);
    CHECK(strcmp(plant::kReadingsUUID, "7697A002-5F72-4B79-B7A4-6632379F2F13") == 0);
    CHECK(strcmp(plant::kDeviceInfoUUID, "7697A003-5F72-4B79-B7A4-6632379F2F13") == 0);
    CHECK(strcmp(plant::kCommandUUID, "7697A004-5F72-4B79-B7A4-6632379F2F13") == 0);
}

TEST(test_makeLocalName_usesLastTwoPrintedBytesUppercaseKeepingLeadingZero) {
    // Printed address AA:BB:CC:DD:0E:F1, in NimBLE order.
    const uint8_t address[6] = {0xF1, 0x0E, 0xDD, 0xCC, 0xBB, 0xAA};
    char name[plant::kLocalNameSize];

    plant::makeLocalName(address, name);

    CHECK(strcmp(name, "TalkingPlant-0EF1") == 0);
}

TEST(test_makeLocalName_isSeventeenCharactersPlusTerminator) {
    const uint8_t address[6] = {0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA};
    char name[plant::kLocalNameSize];

    plant::makeLocalName(address, name);

    CHECK_EQ(strlen(name), 17);
    CHECK_EQ(name[17], 0);
    CHECK(strcmp(name, "TalkingPlant-EEFF") == 0);
}
