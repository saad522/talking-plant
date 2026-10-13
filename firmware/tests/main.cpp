#include "check.h"

TEST(test_runner_runsRegisteredTests) {
    CHECK_EQ(1 + 1, 2);
}

int main() {
    for (int i = 0; i < check::testCount(); i++) {
        check::registry()[i].run();
    }
    printf("%d tests, %d failures\n", check::testCount(), check::failureCount());
    return check::failureCount();
}
