#include "ReadingSchedule.h"
#include "check.h"

TEST(test_readingSchedule_isDueBeforeFirstReading) {
    plant::ReadingSchedule schedule(30);

    CHECK(schedule.isDue(0));
}

TEST(test_readingSchedule_notDueOneMillisecondBeforeInterval) {
    plant::ReadingSchedule schedule(30);
    schedule.markTaken(1000);

    CHECK(!schedule.isDue(1000 + 29999));
}

TEST(test_readingSchedule_dueExactlyAtInterval) {
    plant::ReadingSchedule schedule(30);
    schedule.markTaken(1000);

    CHECK(schedule.isDue(1000 + 30000));
}

TEST(test_readingSchedule_handlesMillisWraparound) {
    plant::ReadingSchedule schedule(30);
    schedule.markTaken(0xFFFFF000u);

    CHECK(!schedule.isDue(0xFFFFF000u + 29999u));
    CHECK(schedule.isDue(0xFFFFF000u + 30000u));
}

TEST(test_readingSchedule_shorterIntervalAppliesFromLastReading) {
    plant::ReadingSchedule schedule(300);
    schedule.markTaken(0);
    CHECK(!schedule.isDue(10000));

    schedule.setIntervalSeconds(10);

    CHECK(schedule.isDue(10000));
}

TEST(test_readingSchedule_constructorClamps) {
    CHECK_EQ(plant::ReadingSchedule(0).intervalSeconds(), 10);
    CHECK_EQ(plant::ReadingSchedule(5000).intervalSeconds(), 3600);
}

TEST(test_readingSchedule_setterClamps) {
    plant::ReadingSchedule schedule(30);

    schedule.setIntervalSeconds(1);
    CHECK_EQ(schedule.intervalSeconds(), 10);

    schedule.setIntervalSeconds(65535);
    CHECK_EQ(schedule.intervalSeconds(), 3600);
}
