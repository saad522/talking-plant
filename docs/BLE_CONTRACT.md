# BLE Contract — v1

Single source of truth for communication between the board (XIAO ESP32-C3) and the
iOS app. All multi-byte values are **little-endian**.

## Advertising

- Local name: `TalkingPlant-XXXX`, where `XXXX` is the last 2 bytes of the board's MAC
  address in uppercase hex.
- The advertisement includes the Plant Service UUID, so iOS can scan with a service
  filter.

## UUIDs

| Item | UUID | Properties |
|---|---|---|
| Plant Service | `7697A001-5F72-4B79-B7A4-6632379F2F13` | — |
| Readings | `7697A002-5F72-4B79-B7A4-6632379F2F13` | Read, Notify |
| Device Info | `7697A003-5F72-4B79-B7A4-6632379F2F13` | Read |
| Command | `7697A004-5F72-4B79-B7A4-6632379F2F13` | Write (with response) |

## Readings characteristic — 16 bytes

Sent on every reading (notify) and available on read (latest reading).

| Offset | Size | Type | Field | Unit / scale | Notes |
|---|---|---|---|---|---|
| 0 | 1 | uint8 | version | — | Always `1` for this contract |
| 1 | 1 | uint8 | flags | bitmask | bit0 soilValid, bit1 lightValid, bit2 envValid, bit3 batteryValid; other bits 0 |
| 2 | 2 | uint16 | soilMillivolts | mV | `analogReadMilliVolts` on the soil pin. Higher = drier |
| 4 | 2 | uint16 | lux | lux | Clamped to 0–65535 |
| 6 | 2 | int16 | temperatureCenti | °C × 100 | 2350 = 23.50 °C |
| 8 | 2 | uint16 | humidityCenti | %RH × 100 | 5520 = 55.20 % |
| 10 | 2 | uint16 | batteryMillivolts | mV | 0 when not measured (battery sense is a V2 feature) |
| 12 | 4 | uint32 | sequence | count | +1 per reading; the first reading after boot is 0 |

Humidity is only clamped to the uint16 range (no clamp to 0–100 %).

A field is only meaningful when its flag bit is set. When a sensor fails to read, the
firmware clears its flag and sends 0 for that field.

**App decoding rules:** reject packets whose length is not 16 or whose version is not 1
(log them, don't crash). The phone timestamps the reading on receipt. Use `sequence` to
drop duplicates; a sequence lower than the previous one means the board rebooted.

### Test fixture

`01 07 C4 09 E8 03 2E 09 90 15 00 00 2A 00 00 00` decodes to:
version 1, flags 0b0111 (soil, light, env valid; battery not), soil 2500 mV,
lux 1000, temperature 23.50 °C, humidity 55.20 %, battery not measured, sequence 42.

## Device Info characteristic — 8 bytes

| Offset | Size | Type | Field | Notes |
|---|---|---|---|---|
| 0 | 1 | uint8 | protocolVersion | `1` |
| 1 | 1 | uint8 | firmwareMajor | |
| 2 | 1 | uint8 | firmwareMinor | |
| 3 | 1 | uint8 | firmwarePatch | |
| 4 | 1 | uint8 | capabilities | bit0 pump, bit1 display, bit2 batterySense (all 0 in V1) |
| 5 | 1 | uint8 | reserved | 0 |
| 6 | 2 | uint16 | intervalSeconds | Current reading interval. Not kept across reboots: the board starts at its default and the app re-sends SET_INTERVAL on connect |

## Command characteristic

First byte is the opcode. Unknown opcodes are ignored by the firmware.

| Opcode | Name | Payload | Behavior |
|---|---|---|---|
| `0x01` | READ_NOW | none | Take a reading and notify immediately |
| `0x02` | SET_INTERVAL | uint16 seconds | Firmware clamps to 10–3600 |
| `0x10` | PUMP_RUN | uint16 milliseconds | V2. Firmware clamps to max 10000 ms; ignored without pump capability |
| `0x11` | PUMP_STOP | none | V2. Stops the pump immediately |

A command write shorter than its opcode needs (for example SET_INTERVAL with fewer than
2 payload bytes) is ignored. Bytes after the expected payload are ignored.

The firmware enforces the pump time limit itself, so a bug in the app can never flood
the plant.

## Moisture calibration (app side)

The board sends raw millivolts; the app converts to a percentage so calibration can
change without reflashing:

```
moisture% = clamp((dryMv - soilMv) / (dryMv - wetMv) * 100, 0, 100)
```

Calibration flow in the app: sensor in dry air → save `dryMv`; sensor in a glass of
water up to its marked line → save `wetMv`. Until calibrated, use placeholder defaults
`dryMv = 2400`, `wetMv = 1100`, and show "not calibrated" in the UI. Replace the
defaults with real values after the hardware arrives.

## Power modes

- **Mode A (MVP):** the board stays awake and connected, sending a reading every
  `intervalSeconds` (default 30 s during development, 300 s normally). Readings taken
  while the phone is away are lost; that is accepted for the MVP.
- **Mode B (later):** deep sleep between readings with short advertising windows and an
  on-board buffer for missed readings. To be designed after the MVP works; it will
  bump the contract to v2.

## Wiring — V1 (XIAO ESP32-C3)

| Part | Pin | Board pin |
|---|---|---|
| Soil sensor | VCC | 3V3 (not 5V, keeps the output inside the ADC range) |
| Soil sensor | GND | GND |
| Soil sensor | AOUT | A0 (D0) |
| BH1750 | VCC / GND | 3V3 / GND |
| BH1750 | SDA / SCL | D4 / D5 (I2C address 0x23, ADDR pin unconnected) |
| AHT20 | VCC / GND | 3V3 / GND |
| AHT20 | SDA / SCL | D4 / D5 (I2C address 0x38) |
| LiPo battery | + / − | BAT+ / BAT− pads on the underside (check polarity) |

A2 (D2) is reserved for battery sensing in V2. Pump and display pins will be assigned
when V2 starts.
