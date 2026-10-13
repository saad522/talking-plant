#include "PlantCommandParser.h"
#include "check.h"

namespace {

template <typename... Bytes>
plant::Command parse(Bytes... bytes) {
    const uint8_t data[] = {static_cast<uint8_t>(bytes)..., 0};
    return plant::parseCommand(data, sizeof...(bytes));
}

}  // namespace

TEST(test_parseCommand_readNow) {
    CHECK(parse(0x01).type == plant::CommandType::ReadNow);
}

TEST(test_parseCommand_setInterval) {
    const auto command = parse(0x02, 0x2C, 0x01);
    CHECK(command.type == plant::CommandType::SetInterval);
    CHECK_EQ(command.value, 300);
}

TEST(test_parseCommand_setIntervalMinimum) {
    const auto command = parse(0x02, 0x0A, 0x00);
    CHECK(command.type == plant::CommandType::SetInterval);
    CHECK_EQ(command.value, 10);
}

TEST(test_parseCommand_setIntervalClampsLow) {
    CHECK_EQ(parse(0x02, 0x00, 0x00).value, 10);
    CHECK_EQ(parse(0x02, 0x05, 0x00).value, 10);
}

TEST(test_parseCommand_setIntervalClampsHigh) {
    CHECK_EQ(parse(0x02, 0x11, 0x0E).value, 3600);
    CHECK_EQ(parse(0x02, 0xFF, 0xFF).value, 3600);
}

TEST(test_parseCommand_pumpRun) {
    const auto command = parse(0x10, 0x10, 0x27);
    CHECK(command.type == plant::CommandType::PumpRun);
    CHECK_EQ(command.value, 10000);
}

TEST(test_parseCommand_pumpRunClampsToMax) {
    const auto command = parse(0x10, 0xFF, 0xFF);
    CHECK(command.type == plant::CommandType::PumpRun);
    CHECK_EQ(command.value, 10000);
}

TEST(test_parseCommand_pumpStop) {
    CHECK(parse(0x11).type == plant::CommandType::PumpStop);
}

TEST(test_parseCommand_ignoresEmptyAndNull) {
    CHECK(parse().type == plant::CommandType::Ignored);
    CHECK(plant::parseCommand(nullptr, 3).type == plant::CommandType::Ignored);
}

TEST(test_parseCommand_ignoresUnknownOpcodes) {
    CHECK(parse(0x03).type == plant::CommandType::Ignored);
    CHECK(parse(0xFF).type == plant::CommandType::Ignored);
}

TEST(test_parseCommand_ignoresShortPayloads) {
    CHECK(parse(0x02).type == plant::CommandType::Ignored);
    CHECK(parse(0x02, 0x0A).type == plant::CommandType::Ignored);
    CHECK(parse(0x10).type == plant::CommandType::Ignored);
    CHECK(parse(0x10, 0x10).type == plant::CommandType::Ignored);
}

TEST(test_parseCommand_ignoresTrailingBytes) {
    CHECK(parse(0x01, 0xAA).type == plant::CommandType::ReadNow);
    const auto command = parse(0x02, 0x2C, 0x01, 0xAA);
    CHECK(command.type == plant::CommandType::SetInterval);
    CHECK_EQ(command.value, 300);
    const auto pumpRun = parse(0x10, 0x10, 0x27, 0xAA, 0xBB);
    CHECK(pumpRun.type == plant::CommandType::PumpRun);
    CHECK_EQ(pumpRun.value, 10000);
    CHECK(parse(0x11, 0xAA).type == plant::CommandType::PumpStop);
}
