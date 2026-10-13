# M7 plan: firmware for the XIAO ESP32-C3

Scope (ROADMAP M7):

- `firmware/talking_plant/talking_plant.ino` implementing `BLE_CONTRACT.md` v1 exactly.
- NimBLE-Arduino 2.x, BH1750 (light), Adafruit AHTX0 (AHT20, temperature/humidity),
  capacitive soil sensor on A0 via `analogReadMilliVolts`.
- Mode A: always awake, a reading every `intervalSeconds`, notify on each reading.
- Serial logging.
- Packet encoding, flags, sequence, Device Info, command parsing, scheduling, and the local
  name live in small plain C++ files with no Arduino dependency, unit-tested on the Mac.

**Done when:** `make -C firmware test` passes and `arduino-cli compile firmware/talking_plant`
succeeds. Nothing here can be checked on hardware until the parts arrive (late October);
those checks are listed per step and collected in section 10 for M8.

Out of scope: Mode B, battery sensing, pump, display, persisting settings in flash, OTA,
pairing/bonding, any change to `BLE_CONTRACT.md` (section 11 lists clarifications to
propose, not apply).

Implementation is split into steps S1–S5, one session each (section 9).

---

## 1. Toolchain

Already installed on this Mac and checked during planning (a throwaway sketch including all
four libraries compiled for the XIAO: 45 % of the 1.2 MB app partition, 7 % of RAM).

| Item | Version |
|---|---|
| arduino-cli | 1.5.1 (Homebrew) |
| Core | `esp32:esp32` **3.3.12** (board manager URL `https://espressif.github.io/arduino-esp32/package_esp32_index.json`) |
| FQBN | `esp32:esp32:XIAO_ESP32C3` (defaults: USB CDC On Boot **Enabled**, 160 MHz, 4 MB, default partitions) |
| NimBLE-Arduino | **2.5.1** |
| BH1750 (claws) | **1.3.0** |
| Adafruit AHTX0 | **2.0.6** |
| Adafruit BusIO | **1.17.4** (AHTX0 dependency) |
| Adafruit Unified Sensor | **1.1.15** (AHTX0 dependency) |
| Host compiler | Apple clang 17 (`c++`), C++17 |

### 1.1 Pinning: `sketch.yaml` profile

Versions are pinned in `firmware/talking_plant/sketch.yaml`, so the build doesn't depend on
whatever is in `~/Documents/Arduino/libraries` (it also holds unrelated Adafruit GFX and
SH110X). Verified with arduino-cli 1.5.1: with `default_profile`, a plain `compile` uses the
profile's FQBN and only the listed libraries, installing them on first use.

```yaml
profiles:
  xiao_esp32c3:
    fqbn: esp32:esp32:XIAO_ESP32C3
    platforms:
      - platform: esp32:esp32 (3.3.12)
        platform_index_url: https://espressif.github.io/arduino-esp32/package_esp32_index.json
    libraries:
      - NimBLE-Arduino (2.5.1)
      - BH1750 (1.3.0)
      - Adafruit AHTX0 (2.0.6)
      - Adafruit BusIO (1.17.4)
      - Adafruit Unified Sensor (1.1.15)
default_profile: xiao_esp32c3
```

### 1.2 Commands

`firmware/Makefile`, three targets:

```bash
make -C firmware test      # host unit tests (seconds)
make -C firmware compile   # arduino-cli compile talking_plant (≈1.5–2 min cold)
make -C firmware clean     # removes firmware/build/
```

`compile` is just `arduino-cli compile talking_plant`; the profile supplies the FQBN. When
running it from Claude Code, use a 10-minute timeout.

### 1.3 SETUP.md changes (S1)

Replace the install block in section 2 with:

```bash
brew install arduino-cli
arduino-cli config init
arduino-cli config add board_manager.additional_urls \
  https://espressif.github.io/arduino-esp32/package_esp32_index.json
arduino-cli core update-index
make -C firmware compile    # first run installs the pinned core and libraries from sketch.yaml
make -C firmware test       # host tests, no board needed
```

Upload and monitor once the board arrives:

```bash
arduino-cli board list                                  # e.g. /dev/cu.usbmodem1101
arduino-cli upload -p <port> firmware/talking_plant
arduino-cli monitor -p <port> -c baudrate=115200
```

Notes to add: USB CDC On Boot is already enabled by default for this board in core 3.3.12;
logs printed before the monitor attaches are lost, so press RESET after opening it. If the
port disappears (crashing sketch), hold BOOT while plugging in USB, then upload.

Also update the firmware line in `CLAUDE.md` → Commands to `make -C firmware compile` and
add `make -C firmware test` (S1).

`.gitignore`: add `firmware/build/`.

---

## 2. Pins, wiring, power

Pin numbers checked in the core's `variants/XIAO_ESP32C3/pins_arduino.h`.

| Function | Board pin | GPIO | Notes |
|---|---|---|---|
| Soil AOUT | A0 / D0 | GPIO2 | ADC1. Strapping pin, see below |
| I2C SDA | D4 | GPIO6 | `Wire.begin()` defaults (`SDA = 6`) |
| I2C SCL | D5 | GPIO7 | `Wire.begin()` defaults (`SCL = 7`) |
| Battery sense (V2) | A2 / D2 | GPIO4 | Reserved, unused in V1 |

Wiring table (matches `BLE_CONTRACT.md`, unchanged):

| Part | Part pin | XIAO pin |
|---|---|---|
| Capacitive soil sensor | VCC / GND / AOUT | 3V3 / GND / A0 |
| BH1750 (GY-302) | VCC / GND / SDA / SCL / ADDR | 3V3 / GND / D4 / D5 / unconnected → 0x23 |
| AHT20 | VCC / GND / SDA / SCL | 3V3 / GND / D4 / D5 → 0x38 |

Power notes:

- Everything runs from the XIAO's **3V3** pin. Never power the soil sensor from 5V: its
  output would exceed the ADC range.
- ESP32-C3 ADC at 11 dB attenuation measures up to about **2.5 V**. The placeholder
  `dryMv = 2400` is close to that ceiling; if dry air reads at a flat ~2500+ mV, the sensor
  is saturating (M8 check).
- Both I2C breakouts normally carry their own pull-ups; no extra resistors.
- Cheap "Capacitive Soil Moisture v1.2" boards sometimes ship with an NE555 that doesn't run
  at 3.3 V. It must be a TLC555 (or equivalent CMOS 555) (M8 check).
- A0 is GPIO2, one of the ESP32-C3 strapping pins. A sensor holding it at 1–2.5 V at power-up
  should not stop the boot, but if the board fails to boot only with the sensor attached,
  this is the first suspect; A1 (GPIO3, also ADC1) is the fallback. Avoid A3/D3 (GPIO5,
  ADC2, unreliable with the radio on).
- LiPo on the BAT pads is optional for V1; USB power is enough for bring-up.

---

## 3. File structure

```
firmware/
├── Makefile                          # test, compile, clean
├── talking_plant/                    # Arduino sketch folder (name must match the .ino)
│   ├── sketch.yaml                   # pinned core + libraries
│   ├── talking_plant.ino             # thin: hardware, NimBLE, loop, Serial
│   └── src/                          # plain C++17, no Arduino.h; compiled by arduino-cli too
│       ├── PlantContract.h/.cpp      # constants, UUID strings, makeLocalName
│       ├── PlantReadingEncoder.h/.cpp
│       ├── PlantDeviceInfoEncoder.h/.cpp
│       ├── PlantCommandParser.h/.cpp
│       └── ReadingSchedule.h/.cpp
└── tests/                            # host only; outside the sketch folder, never flashed
    ├── check.h                       # ~40-line test helper
    ├── main.cpp                      # runs every test, exit code = failures
    ├── PlantContractTests.cpp
    ├── PlantReadingEncoderTests.cpp
    ├── PlantDeviceInfoEncoderTests.cpp
    ├── PlantCommandParserTests.cpp
    └── ReadingScheduleTests.cpp
```

Rules for `src/`:

- Only `<stdint.h>`, `<stddef.h>`, `<math.h>`, `<string.h>`. No `Arduino.h`, no NimBLE,
  no heap, no `std::string`.
- Everything in `namespace plant`.
- Write multi-byte fields with explicit shifts, never `memcpy` of a struct or value. Both the
  Mac and the ESP32-C3 are little-endian, so a `memcpy` bug would pass the host tests;
  shifts make the byte order visible.
- arduino-cli compiles `src/` recursively; the .ino includes `"src/PlantContract.h"` etc.
  (layout verified during planning).

Names mirror the iOS side: `PlantReadingMapper` ↔ `PlantReadingEncoder`,
`PlantDeviceInfoMapper` ↔ `PlantDeviceInfoEncoder`, `PlantDeviceCommandMapper` ↔
`PlantCommandParser`.

---

## 4. Pure C++ API

### 4.1 `PlantContract.h`

```cpp
namespace plant {
constexpr uint8_t kProtocolVersion = 1;
constexpr size_t  kReadingLength = 16;
constexpr size_t  kDeviceInfoLength = 8;

constexpr const char* kServiceUUID     = "7697A001-5F72-4B79-B7A4-6632379F2F13";
constexpr const char* kReadingsUUID    = "7697A002-5F72-4B79-B7A4-6632379F2F13";
constexpr const char* kDeviceInfoUUID  = "7697A003-5F72-4B79-B7A4-6632379F2F13";
constexpr const char* kCommandUUID     = "7697A004-5F72-4B79-B7A4-6632379F2F13";

constexpr const char* kLocalNamePrefix = "TalkingPlant-";
constexpr size_t kLocalNameSize = 18;           // 13 + 4 hex + '\0'

enum ReadingFlag : uint8_t { kSoilValid = 1 << 0, kLightValid = 1 << 1,
                             kEnvValid = 1 << 2, kBatteryValid = 1 << 3 };

constexpr uint16_t kMinIntervalSeconds = 10;
constexpr uint16_t kMaxIntervalSeconds = 3600;
constexpr uint16_t kMaxPumpMilliseconds = 10000;

// addressLE is NimBLE's getVal() order: index 0 is the LAST byte of "AA:BB:CC:DD:EE:FF".
// Writes "TalkingPlant-EEFF" (uppercase hex).
void makeLocalName(const uint8_t addressLE[6], char out[kLocalNameSize]);
}
```

### 4.2 `PlantReadingEncoder.h`

```cpp
struct SensorSample {
    bool soilValid;  uint32_t soilMillivolts;          // analogReadMilliVolts
    bool lightValid; float lux;                        // BH1750 returns < 0 on error
    bool envValid;   float temperatureC; float humidityPercent;
};

class ReadingSequence {                                // 0 after boot, +1 per reading, wraps
public:
    uint32_t take();                                   // returns current, then increments
private:
    uint32_t next_ = 0;
};

void encodeReading(const SensorSample& sample, uint32_t sequence, uint8_t out[kReadingLength]);
```

Encoding rules (all in `encodeReading`, all tested):

| Field | Rule |
|---|---|
| version | always 1 |
| flags | only bits 0–2 can be set; bit 3 (battery) and bits 4–7 always 0 |
| soil | invalid → flag clear, 0. Valid → `min(mV, 65535)` |
| lux | invalid, NaN, or negative → flag clear, 0. Valid → round, clamp to 0–65535 |
| temperature + humidity | one flag. Invalid or either is NaN → flag clear, both 0. Valid → `lroundf(x * 100)`, clamped to int16 / uint16 range **before** casting |
| battery | always 0 |
| sequence | the given value, uint32 little-endian |

Rounding matters: `55.2f * 100` is 5519.99…; truncation would give 5519, the fixture needs
5520 (`90 15`).

### 4.3 `PlantDeviceInfoEncoder.h`

```cpp
struct FirmwareVersion { uint8_t major, minor, patch; };
void encodeDeviceInfo(FirmwareVersion version, uint16_t intervalSeconds, uint8_t out[kDeviceInfoLength]);
```

protocolVersion 1, capabilities 0 (V1), reserved 0, interval little-endian.

### 4.4 `PlantCommandParser.h`

```cpp
enum class CommandType : uint8_t { Ignored, ReadNow, SetInterval, PumpRun, PumpStop };
struct Command { CommandType type; uint16_t value; };   // value: seconds or ms, already clamped

Command parseCommand(const uint8_t* data, size_t length);
```

| Input | Result |
|---|---|
| empty / `nullptr` | Ignored |
| `01` | ReadNow |
| `02 lo hi` | SetInterval, value clamped to 10–3600 |
| `10 lo hi` | PumpRun, value clamped to ≤ 10000 |
| `11` | PumpStop |
| unknown opcode | Ignored |
| `02` or `10` with < 2 payload bytes | Ignored |
| extra trailing bytes | ignored, command still parsed |

Pump commands are parsed and clamped so the safety limit is tested code from day one, but
the .ino ignores them in V1 (capabilities = 0) and only logs them.

### 4.5 `ReadingSchedule.h`

```cpp
class ReadingSchedule {
public:
    explicit ReadingSchedule(uint16_t intervalSeconds);   // clamps 10–3600
    uint16_t intervalSeconds() const;
    void setIntervalSeconds(uint16_t seconds);             // clamps 10–3600
    bool isDue(uint32_t nowMs) const;                      // true before the first reading
    void markTaken(uint32_t nowMs);
};
```

`isDue` uses `nowMs - lastMs >= interval * 1000` with unsigned math, so the `millis()`
wraparound after 49.7 days is handled. A new interval applies from the last reading, so
going from 300 s to 10 s takes effect within 10 s.

---

## 5. Host tests

`tests/check.h`, no framework:

```cpp
// CHECK(cond), CHECK_EQ(actual, expected), CHECK_BYTES(actual, expected, length)
// Print file:line and a hex diff on failure, and count failures.
// TEST(name) declares `void name()` and registers it in a static list.
```

`tests/main.cpp` runs every registered test, prints `N tests, M failures`, and returns `M`
(non-zero fails `make`).

Makefile `test` target:

```make
CXXFLAGS = -std=c++17 -Wall -Wextra -Werror -pedantic -fsanitize=address,undefined \
           -fno-sanitize-recover=all -Italking_plant/src
test:
	mkdir -p build
	$(CXX) $(CXXFLAGS) talking_plant/src/*.cpp tests/*.cpp -o build/host_tests
	./build/host_tests
```

UBSan catches a float-to-int cast overflow if clamping is ever done after the cast.

Test list (names in `test_<unit>_<behavior>` style, matching the iOS naming idea):

**PlantContractTests**
- UUID strings equal the contract text (same strings as `PlantBluetoothContractTests`).
- `makeLocalName` with NimBLE order `{F1, 0E, DD, CC, BB, AA}` → `TalkingPlant-0EF1`
  (leading zero kept, uppercase, uses the last two printed bytes).
- Name is 17 characters + terminator.

**PlantReadingEncoderTests**
- Contract fixture: `{soil 2500, lux 1000, 23.5 °C, 55.2 %}`, sequence 42 →
  `01 07 C4 09 E8 03 2E 09 90 15 00 00 2A 00 00 00`.
- Each sensor failing alone: soil → flags `06`, bytes 2–3 zero; light (lux = -2, NaN, or
  `lightValid = false`) → `05`, bytes 4–5 zero; env (flag false, temp NaN, or humidity NaN)
  → `03`, bytes 6–9 zero.
- All failing → `01 00 00 … 00` + sequence.
- Battery bytes 10–11 always zero, bit 3 never set, bits 4–7 never set.
- Little-endian: soil `0x1234` → `34 12`; sequence `0x01020304` → `04 03 02 01` (same as
  iOS `test_map_decodesSequenceAsLittleEndian`); sequence `0xFFFFFFFF` → `FF FF FF FF`.
- Signed temperature: -10.5 → `E6 FB`; -0.01 → `FF FF` (mirrors iOS
  `test_map_decodesSignedTemperature`).
- Clamping: lux 70000 → `FF FF`; lux 0.4 → `00 00`, 0.6 → `01 00`; soil 70000 mV →
  `FF FF`; temperature 400 → `FF 7F`, -400 → `00 80`; humidity 700 % → `FF FF`.
- Rounding: humidity 55.2 → `90 15` (not `8F 15`).
- `ReadingSequence`: 0, 1, 2…; starting at `0xFFFFFFFF` wraps to 0.

**PlantDeviceInfoEncoderTests**
- Version 1.2.3, interval 300 → `01 01 02 03 00 00 2C 01` (the iOS
  `PlantDeviceInfoMapperTests` fixture).
- Interval 3600 → `10 0E`; capabilities and reserved are always 0.

**PlantCommandParserTests** — inputs are the exact bytes produced by
`PlantDeviceCommandMapperTests`:
- `01` → ReadNow. `02 2C 01` → SetInterval 300. `02 0A 00` → 10. `10 10 27` → PumpRun 10000.
  `10 FF FF` → PumpRun 10000 (clamped). `11` → PumpStop.
- SetInterval clamping: 0, 5 → 10; 3601, 65535 → 3600.
- Ignored: empty, `nullptr`, `03`, `FF`, `02`, `02 0A`, `10`, `10 10`.
- Trailing bytes: `01 AA` → ReadNow; `02 2C 01 AA` → 300.

**ReadingScheduleTests**
- Due before the first reading. Not due 1 ms before the interval, due exactly at it.
- `millis()` wraparound: taken at `0xFFFFF000`, due at `0xFFFFF000 + interval` (wrapped).
- Shortening the interval applies from the last reading; constructor and setter clamp.

---

## 6. Behaviour (`talking_plant.ino`)

Target size ≈ 200 lines. Everything below is glue around section 4.

### 6.1 Constants

```cpp
constexpr uint8_t kSoilPin = A0;
constexpr plant::FirmwareVersion kFirmwareVersion{0, 1, 0};      // decision 1 (section 11)
constexpr uint16_t kDefaultIntervalSeconds = 30;                 // decision 2 (section 11)
constexpr int kSoilSamples = 8;                                  // averaged per reading
```

### 6.2 `setup()`

1. `Serial.begin(115200)`, wait for USB at most 2 s (`while (!Serial && millis() < 2000)`),
   so the board still boots on a charger or battery.
2. `analogSetPinAttenuation(kSoilPin, ADC_11db)` (explicit, even though it's the default).
3. `Wire.begin()`. Probe 0x23 and 0x38 and log which answered.
4. `lightReady = lightMeter.begin()` (continuous high-res), `envReady = aht.begin()`.
   Wait 200 ms so the BH1750's first measurement exists.
5. NimBLE:
   - `NimBLEDevice::init("")`, then build the name from `NimBLEDevice::getAddress().getVal()`
     with `plant::makeLocalName`, and `NimBLEDevice::setDeviceName(name)` so the GAP name
     matches the advertised one.
   - Server with callbacks; `advertiseOnDisconnect(true)`.
   - Plant Service with Readings (`READ | NOTIFY`; NimBLE 2.x adds the CCCD itself),
     Device Info (`READ`), Command (`WRITE` only, so writes are with response).
   - Device Info value from `encodeDeviceInfo`.
6. Take the first reading (sequence 0) before advertising, so a read never returns an empty
   value.
7. Advertising: `enableScanResponse(true)` **before** `setName(name)` (NimBLE 2.5.1 puts the
   name in the scan response only if it's enabled first), `addServiceUUID(kServiceUUID)`,
   `start()`. Reason: flags (3) + 128-bit UUID (18) + name (19) = 40 bytes > 31. The UUID
   stays in the main packet so iOS can scan with a service filter; iOS gets the name from
   the scan response.
8. Log the boot line.

### 6.3 `loop()`

1. If a new interval was requested: `schedule.setIntervalSeconds`, re-encode Device Info,
   `setValue`, log.
2. If READ_NOW was requested or `schedule.isDue(millis())`: take a reading.
3. `delay(10)`.

`takeReading()`:

- Soil: average `kSoilSamples` × `analogReadMilliVolts(kSoilPin)`; always valid
  (see decision 4, section 11).
- Light: if `!lightReady`, retry `begin()`. Valid when ready and `readLightLevel() >= 0`.
- Env: if `!envReady`, retry `begin()`. Valid when `aht.getEvent(&humidity, &temp)` returns
  true.
- `encodeReading(sample, sequence.take(), packet)`, then `readings->setValue(packet, 16)`
  and `readings->notify()`. `setValue` first, so a read always returns the latest packet.
  `notify()` with no subscriber is harmless.
- `schedule.markTaken(millis())`, log.

The retry means a loose I2C wire that's fixed while running recovers without a reboot.

### 6.4 BLE callbacks

NimBLE callbacks run on the NimBLE host task, not in `loop()`. They never touch I2C or the
ADC:

- `onWrite` (Command): `parseCommand`, log, then set `std::atomic<bool> readNowRequested` or
  `std::atomic<uint16_t> requestedInterval` (0 = none). Pump commands: log "ignored, no
  pump". `loop()` does the work.
- `onConnect`: log peer address. Advertising stops (one phone at a time).
- `onDisconnect`: log reason; advertising restarts through `advertiseOnDisconnect(true)`.
  Log "advertising" so it's visible.
- `onSubscribe` (Readings): log subscribe/unsubscribe. Useful in M8.

The 16-byte packet fits the default ATT MTU (23 → 20 bytes of payload), so no MTU request.

### 6.5 Sensor failure

Per the contract: a failed sensor clears its flag and sends 0. The firmware never sends a
stale value as valid, never skips a reading because one sensor failed, and never stops
advertising because of a sensor.

---

## 7. Serial logs

115200 baud, one line per event, prefixed by area. Example:

```
[boot] TalkingPlant-0EF1 fw 0.1.0 addr aa:bb:cc:dd:0e:f1 interval 30 s
[i2c] 0x23 BH1750 ok, 0x38 AHT20 missing
[read] #0 soil 2500 mV, lux 1000, env --, flags 0x03 | 01 03 C4 09 E8 03 00 00 00 00 00 00 00 00 00 00
[ble] connected 5a:3c:..:..
[ble] readings subscribed
[cmd] SET_INTERVAL 5 s -> 10 s
[cmd] PUMP_RUN 10000 ms ignored, no pump
[cmd] ignored 03 (unknown)
[ble] disconnected, reason 0x13, advertising
```

The hex dump of every packet can be pasted straight into a Swift test.

---

## 8. Cross-check with the iOS side

No test runs across both languages; the same byte arrays live in both suites. If the
contract changes, the doc, both suites, the Swift decoders and the firmware change together
(CLAUDE.md).

| Contract part | iOS decoder/encoder | iOS tests | Firmware | Firmware tests | Shared bytes |
|---|---|---|---|---|---|
| UUIDs, name prefix, lengths | `PlantShared/Contract/PlantBluetoothContract.swift`, `PlantCharacteristic.swift` | `PlantBluetoothContractTests` | `PlantContract.h` | `PlantContractTests` | UUID strings |
| Readings (16 B) | `PlantMonitor/API/PlantReadingMapper.swift` | `PlantReadingMapperTests` | `PlantReadingEncoder` | `PlantReadingEncoderTests` | contract fixture; `E6 FB` = -10.50 °C; sequence `04 03 02 01` |
| Readings, simulated | `PlantShared/Client/SimulatedPeripheralClient.swift` (`makePacket`, flags `0b0111`, battery 0) | `SimulatedPeripheralClientTests` | — | — | same layout |
| Device Info (8 B) | `PlantDevice/API/PlantDeviceInfoMapper.swift` | `PlantDeviceInfoMapperTests` | `PlantDeviceInfoEncoder` | `PlantDeviceInfoEncoderTests` | `01 01 02 03 00 00 2C 01` |
| Command | `PlantDevice/API/PlantDeviceCommandMapper.swift` (encodes) | `PlantDeviceCommandMapperTests` | `PlantCommandParser` (decodes) | `PlantCommandParserTests` | `01`, `02 2C 01`, `02 0A 00`, `10 10 27`, `10 FF FF`, `11` |

Things noticed on the iOS side (not changed in M7):

- `CoreBluetoothPeripheralClient` (M6) isn't in the repo yet, so the app can't talk to the
  board until M6 is done. The first M8 checks use a generic BLE app (nRF Connect or
  LightBlue) — decision 5 (section 11).
- `PlantDeviceInfoMapper` reads `protocolVersion` but doesn't reject a value other than 1,
  unlike `PlantReadingMapper`. Harmless with this firmware.
- The simulator's first read returns sequence 0 and its first notify sequence 1. The
  firmware's first reading is sequence 0, notified and readable. Both fit the app's rules
  (duplicates dropped, lower sequence = reboot).

---

## 9. Steps (one session each)

Every step: run `make -C firmware test` (from S2) and `make -C firmware compile`, leave
changes uncommitted, short summary.

### S1 — Toolchain and skeleton

- Files: `firmware/talking_plant/sketch.yaml`, `firmware/Makefile`, `firmware/tests/check.h`,
  `firmware/tests/main.cpp` (one trivial test so the runner is proven), a minimal
  `talking_plant.ino` (Serial boot line only), `.gitignore` (`firmware/build/`),
  `docs/SETUP.md` section 2, `CLAUDE.md` Commands.
- Verify: `make -C firmware test` prints `1 tests, 0 failures`; temporarily flip the test to
  fail and check `make` exits non-zero; `make -C firmware compile` succeeds.
- M8: upload works, boot line shows in `arduino-cli monitor`.

### S2 — Contract constants and Readings encoder

- Files: `src/PlantContract.h/.cpp`, `src/PlantReadingEncoder.h/.cpp`,
  `tests/PlantContractTests.cpp`, `tests/PlantReadingEncoderTests.cpp`.
- Verify: all tests in section 5 for these two units pass, with sanitizers on; compile still
  succeeds (the .ino includes the headers but doesn't use them yet).
- M8: none directly (covered by S4/S5 checks).

### S3 — Device Info, commands, schedule

- Files: `src/PlantDeviceInfoEncoder.h/.cpp`, `src/PlantCommandParser.h/.cpp`,
  `src/ReadingSchedule.h/.cpp` and their tests.
- Verify: section 5 tests pass; compile succeeds.
- M8: none directly.

### S4 — Sensors, schedule and logs in the .ino (no BLE yet)

- Files: `talking_plant.ino`.
- Work: constants (6.1), setup steps 1–4 and 8, `takeReading()` without `setValue`/`notify`,
  `loop()` with the schedule, I2C probe, retry logic, log lines with packet hex.
- Verify: compile succeeds; host tests still pass; read through 6.3/6.5 as a checklist.
- M8: I2C probe finds 0x23 and 0x38; lux changes with a hand over the sensor; temperature
  and humidity are plausible; breath on the AHT20 raises humidity; pulling SDA clears both
  I2C flags and the next readings recover after reconnecting; soil drops in water and rises
  in air; readings every 30 s.

### S5 — BLE

- Files: `talking_plant.ino`.
- Work: setup step 5–7, callbacks (6.4), `setValue` + `notify` in `takeReading()`, command
  handling in `loop()`, Device Info update on interval change. Add a status note under M7
  in `docs/ROADMAP.md`.
- Verify: compile succeeds; host tests pass; review against 6.2 (scan-response order,
  properties), 6.4 (no I2C in callbacks), and section 3 of `BLE_CONTRACT.md` line by line.
- M8: see section 10.

---

## 10. M8 bring-up checklist (real board)

With nRF Connect or LightBlue on the iPhone, then with the app once M6 exists:

1. Board boots with all three sensors attached (A0 strapping concern, section 2).
2. Scanner shows `TalkingPlant-XXXX`; `XXXX` equals the last 4 hex digits of the address in
   the boot log (catches byte-order mistakes in `makeLocalName`).
3. Scanning filtered by the service UUID finds the board.
4. Service has three characteristics with the right UUIDs and properties (Readings:
   read + notify, Device Info: read, Command: write).
5. Reading Readings returns 16 bytes matching the latest `[read]` hex line in the log.
6. Subscribing gives a notify every interval; sequence goes +1 each time; after RESET it
   restarts at 0.
7. Device Info reads `01 00 01 00 00 00 1E 00` (fw 0.1.0, interval 30).
8. Write `01` → immediate notify. Write `02 0A 00` → readings every 10 s and Device Info
   interval `0A 00`. Write `02 05 00` → clamped to 10. Write `10 10 27`, `03` → logged and
   ignored.
9. Disconnect in the scanner app → log shows "advertising"; reconnect works. Walk out of
   range and back → reconnects.
10. Unplug one I2C sensor → its flag clears, fields 0, other sensors unaffected; plug back →
    recovers without reboot.
11. Run from a USB charger (no computer): readings keep coming at the interval (checks that
    Serial writes don't block without a USB host; if they do, add
    `Serial.setTxTimeoutMs(0)`, which exists in core 3.3.12).
12. Soil: dry air mV below ~2500 (not saturated), glass of water clearly lower; note both
    for the app's calibration. Check the 555 chip is a TLC555.
13. Leave it running overnight: no resets in the log, sequence continuous.

---

## 11. Decisions

1. **Firmware version.** `0.1.0` until M8 passes, then `1.0.0`.
2. **Default interval.** 30 s now; switch the constant to 300 s at the end of M8.
3. **Persist SET_INTERVAL?** No. The interval is not persisted; a reboot goes back to the
   default and the app re-sends it on connect.
4. **Soil sensor failure.** Decide in M8, after seeing what an unplugged pin reads. Add a
   disabled threshold constant later, in S4.
5. **M6 before M8.** Do M6 first. Use nRF Connect (or LightBlue) only as a first smoke test.
6. **Contract clarifications.** Add them to `BLE_CONTRACT.md` in S5 (first sequence after boot
   is 0; too-short command payloads and trailing bytes are ignored; the interval isn't kept
   across reboots; humidity is clamped only to the uint16 range).
7. **Pump commands in the parser.** Parse and clamp `PUMP_RUN` now; V1 still ignores it.
