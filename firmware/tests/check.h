// Minimal host test helper: no framework.
#pragma once

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

namespace check {

struct Test {
    const char* name;
    void (*run)();
};

constexpr int kMaxTests = 256;

inline Test* registry() {
    static Test tests[kMaxTests];
    return tests;
}

inline int& testCount() {
    static int count = 0;
    return count;
}

inline int& failureCount() {
    static int count = 0;
    return count;
}

inline bool registerTest(const char* name, void (*run)()) {
    if (testCount() < kMaxTests) {
        registry()[testCount()++] = Test{name, run};
    }
    return true;
}

inline void fail(const char* file, int line, const char* message) {
    printf("%s:%d: FAIL %s\n", file, line, message);
    failureCount()++;
}

inline void failEqual(const char* file, int line, long long actual, long long expected) {
    printf("%s:%d: FAIL expected %lld, got %lld\n", file, line, expected, actual);
    failureCount()++;
}

inline void failBytes(const char* file, int line, const uint8_t* actual,
                      const uint8_t* expected, size_t length) {
    printf("%s:%d: FAIL bytes differ\n  expected:", file, line);
    for (size_t i = 0; i < length; i++) printf(" %02X", expected[i]);
    printf("\n  actual:  ");
    for (size_t i = 0; i < length; i++) printf(" %02X", actual[i]);
    printf("\n");
    failureCount()++;
}

}  // namespace check

#define TEST(name)                                                              \
    void name();                                                                \
    static const bool name##_registered = check::registerTest(#name, name);     \
    void name()

#define CHECK(cond)                                                             \
    do {                                                                        \
        if (!(cond)) check::fail(__FILE__, __LINE__, #cond);                    \
    } while (0)

#define CHECK_EQ(actual, expected)                                              \
    do {                                                                        \
        long long a_ = static_cast<long long>(actual);                          \
        long long e_ = static_cast<long long>(expected);                        \
        if (a_ != e_) check::failEqual(__FILE__, __LINE__, a_, e_);             \
    } while (0)

#define CHECK_BYTES(actual, expected, length)                                   \
    do {                                                                        \
        if (memcmp((actual), (expected), (length)) != 0)                        \
            check::failBytes(__FILE__, __LINE__, (actual), (expected), (length)); \
    } while (0)
