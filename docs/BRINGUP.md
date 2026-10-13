# Bring-up day

Step by step, first time, real board. Each step says what to do, what you should see, and
what to do if you don't. Tick the boxes as you go. Fill in the tables at the end of each
part; they are what milestone step S10 needs.

Rule of thumb: **change one thing at a time**, check, then move on. If something is
wrong, the answer is almost always in the serial log.

Troubleshooting rows are in section 10. "→ T6" means troubleshooting row 6.

## 0. Before you start

**Parts**

- [ ] XIAO ESP32-C3 ×2 (one is a spare) and its U.FL antenna
- [ ] Capacitive soil sensor, BH1750 (GY-302), AHT20
- [ ] Breadboard, female-female and male-female Dupont wires
- [ ] USB-C **data** cable (charge-only cables are the most common "no port" cause)

**Tools**

- [ ] Soldering iron and solder (see step 2, headers)
- [ ] Glass of water, paper towel, a potted plant, tape
- [ ] Multimeter: **optional until you buy one.** Every multimeter check below is marked
      *(multimeter, optional)*. Skip them for now; the serial log tells you almost the same.

**Phones**

- [ ] 17 Pro: the app, DEBUG build, with the launch argument `-PlantReadingInterval 30`
      ticked in the scheme for the day (30 s readings instead of 5 min).
- [ ] 13 Pro: **not** running the test peripheral (two `TalkingPlant-*` devices would
      confuse the picker).
- [ ] In the app, if `TalkingPlant-TEST` is paired: Settings → *Forget sensor*.

**Mac: prove the toolchain before the board is plugged in**

```bash
make -C firmware test
make -C firmware compile
```

You should see both finish without errors. If not, fix `docs/SETUP.md` section 2 first;
nothing below will work without it.

## 1. Check what you actually got

Look at each part and fill the table. Local shops sell different variants.

| Part | Look for | Expected | What you found |
|---|---|---|---|
| XIAO ESP32-C3 | "XIAO ESP32C3" silkscreen, antenna in the bag | Antenna present. **Always attach it before powering.** Without it BLE range is a few cm. | |
| Soil sensor | PCB version (v1.2 / v2.0); the 8-pin chip marking; the 3-pin regulator | Chip **TLC555**, **TLC555I**, **7555** or **LMC555** (CMOS, works at 3.3 V). A plain **NE555** does not run at 3.3 V and the board is unusable. Regulator "662K". Pin order VCC / GND / AOUT (read the label; it varies). | |
| BH1750 | "GY-302", chip "BH1750FVI", pins VCC GND SCL SDA ADDR | ADDR left unconnected → address 0x23 (ADDR high → 0x5C). | |
| AHT20 | "AHT20" (or AHT10, or an AHT20+BMP280 combo) | Address 0x38. The firmware's library handles AHT10 and AHT20; a BMP280 at 0x76 or 0x77 is ignored. | |
| Both I2C boards | Supply range printed; two small resistors near SDA/SCL (pull-ups, often marked 472 or 103) | Works at 3.3 V; pull-ups present. | |

*(multimeter, optional)* With everything unpowered, measure SDA to VCC on each I2C board:
about 2–10 kΩ means pull-ups are present.

**If a marking isn't what's expected:** write it down, keep going with the parts that are
fine, and note it for S10. An NE555 soil sensor needs replacing (→ T9).

## 2. Solder the headers

The XIAO and many breakouts ship with loose pin headers. Without them you'd be holding
wires against bare pads, which gives intermittent contacts (→ T7). Do this once, with the
USB unplugged.

1. [ ] Put the long side of the XIAO's headers through a breadboard, short side up, set the
       board on top, and solder each pin. Check every joint: a small shiny cone, no bridge
       to the neighbouring pin.
2. [ ] Do the same for the BH1750 and AHT20 if they came with loose headers (only the pins
       you use: VCC, GND, SDA, SCL).
3. [ ] The soil sensor has a connector already; no soldering needed.
4. [ ] Don't solder the antenna; the U.FL connector just snaps on. Press it straight down
       until it clicks, then attach the antenna.

You should see: clean, shiny joints and the board sitting flat in the breadboard.
If you've never soldered: practise on the spare board first. If a joint looks dull or
balled up, reheat it with fresh solder for 2 seconds.

## 3. Wiring

Rules: **USB unplugged while wiring.** Everything on **3V3**, never 5V. Add one sensor at
a time and check between each.

| Sensor pin | Board pin |
|---|---|
| Soil VCC | 3V3 |
| Soil GND | GND |
| Soil AOUT | A0 (D0 / GPIO2) |
| BH1750 VCC / GND | 3V3 / GND |
| BH1750 SDA / SCL | D4 / D5 |
| BH1750 ADDR | not connected |
| AHT20 VCC / GND | 3V3 / GND |
| AHT20 SDA / SCL | D4 / D5 (same two pins as the BH1750) |

Top view, USB-C at the top. Check against the silkscreen on your board:

```
                    ┌──────[ USB-C ]──────┐
 soil AOUT ──── D0 / A0  GPIO2      5V     (unused, never)
                D1 / A1  GPIO3      GND  ── GND rail ── soil GND, BH1750 GND, AHT20 GND
                D2 / A2  GPIO4      3V3  ── 3V3 rail ── soil VCC, BH1750 VCC, AHT20 VCC
                D3       GPIO5      D10
 SDA bus ────── D4 / SDA GPIO6      D9     (BOOT button pin, leave free)
 SCL bus ────── D5 / SCL GPIO7      D8     (strapping pin, leave free)
                D6 / TX  GPIO21     D7 / RX
                    └─────────────────────┘
 Antenna on the U.FL connector. A2 is reserved for battery sense (V2). Fallback soil pin: A1.
```

Order of work: (0) bare board → (1) soil sensor → (2) BH1750 → (3) AHT20. Steps 4–6
below tell you when to add each one, so **don't wire the sensors yet**: first flash the
bare board.

## 4. Flash the board

1. [ ] Plug the XIAO in with the antenna attached. Find its port:

   ```bash
   arduino-cli board list
   ls /dev/cu.usbmodem*
   ```

   You should see one `/dev/cu.usbmodemXXXX` (the board name may say "Unknown"; that's
   fine). Replace `XXXX` below with yours.
   **If there's no port** → T1.

2. [ ] Compile and upload:

   ```bash
   make -C firmware compile
   arduino-cli compile --upload -p /dev/cu.usbmodemXXXX firmware/talking_plant
   ```

   You should see "Hard resetting via RTS pin" at the end. There's no driver to install:
   the C3 uses its built-in USB.
   **If it fails** → T2. In short: close any open serial monitor, then hold **BOOT**, tap
   **RESET**, release BOOT, run `arduino-cli board list` again (the port name can change),
   upload, then tap RESET.

3. [ ] Flash the spare board the same way once, to know it works. It gets its own
       `TalkingPlant-XXXX` name. Then keep using the first board.

## 5. Serial monitor, stage by stage

```bash
arduino-cli monitor -p /dev/cu.usbmodemXXXX -c baudrate=115200
```

Boot lines printed before the monitor attaches are lost, and RESET re-enumerates the USB
port, which can close the monitor. To catch the boot lines, run it in a loop (the sketch
waits up to 2 s for USB):

```bash
while true; do arduino-cli monitor -p /dev/cu.usbmodemXXXX -c baudrate=115200; sleep 0.3; done
```

The Arduino IDE 2 Serial Monitor also works and reconnects by itself. *Note for later:
write down here which one worked best on the day.*

Press RESET. A fully wired board prints this at boot, in this order (`[read] #0` comes
**before** `[boot]`):

```
[i2c] 0x23 BH1750 ok, 0x38 AHT20 ok
[i2c] found: 0x23 0x38
[read] #0 soil 2431 mV, lux 312, env 23.41 C 48.20 %, flags 0x07 | 01 07 7F 09 38 01 25 09 D4 12 00 00 00 00 00 00
[boot] TalkingPlant-0EF1 fw 0.1.0 addr aa:bb:cc:dd:0e:f1 interval 30 s
[read] #1 …            (then one line every 30 s)
```

The second line is the **I2C scan**: it lists every address that answered, whatever the
module is. Use it when `BH1750` or `AHT20` says `missing`: `found: none` means a wiring
or power fault; `found: 0x5C` means the BH1750's ADDR pin is high; extra addresses such as
`0x77` are other chips on a combo board.

Add one part at a time. After each, RESET (or unplug and replug USB, wiring with USB
**unplugged**) and compare:

| Stage | Wire | Expected in the log | If not |
|---|---|---|---|
| 0 · bare board | nothing | Both I2C `missing`, `found: none`, `lux --, env --`, `flags 0x01`, soil = some floating value | No output at all → T3 |
| 1 · soil | soil sensor | `flags 0x01`. Air ≈ 2200–2500 mV; sensor in water up to the line ≈ 1000–1300 mV; changes within one reading | Flat ≥ 2500 or flat ~0, or very slow → T9, T10, T11. Board only fails to boot with the sensor attached → T4 |
| 2 · + BH1750 | BH1750 | `0x23 BH1750 ok`, `found: 0x23`, `flags 0x03`. Hand over it → lux drops; phone torch → lux rises | `missing` → T6 |
| 3 · + AHT20 | AHT20 | `0x38 AHT20 ok`, `found: 0x23 0x38`, `flags 0x07`. Room-like values; breathe on it → humidity rises | `missing` → T6. Temperature 2–3 °C high → it's next to the board or in sun |

*(multimeter, optional)* With USB plugged in: the 3V3 pin ≈ 3.3 V; the soil AOUT pin in
air ≈ 2.2–2.6 V. It should agree with the `[read]` soil mV within about 50 mV.

**Soil-failure measurements (table A).** While at stages 0 and 1, write down 10 soil
values for each case:

| Case | What | 10 values (mV) | Max | Min |
|---|---|---|---|---|
| (a) | Bare board, nothing on A0 (floating) | | | |
| (b) | Soil sensor, AOUT unplugged (VCC and GND connected) | | | |
| (c) | Soil sensor, VCC unplugged, AOUT still on A0 | | | |
| (d) | Soil sensor in water (the lowest real value) | | | |

Final check at stage 3: unplug SDA while running. The next readings show `flags 0x01` with
the fields at 0. Plug it back: it recovers without a reboot.

## 6. First connection: nRF Connect on the 17 Pro

Install **nRF Connect** (free) from the App Store. Before the app, prove the board speaks
the contract.

1. [ ] Scanner → find `TalkingPlant-XXXX`, where XXXX is the last 4 hex digits of `addr` in
       the `[boot]` line. Service `7697A001-…`.
       **Not in the list** → T5.
2. [ ] Connect. Serial shows `[ble] connected …`.
3. [ ] Readings characteristic: read it → same bytes as the latest `[read]` line. Enable
       notifications: a new value every 30 s, sequence +1 each time, serial shows
       `[ble] readings subscribed`.
4. [ ] Device Info: read it → `01 00 01 00 00 00 1E 00`.
5. [ ] Command characteristic (write request, byte array). Expect in the serial log:

   | You write | You should see |
   |---|---|
   | `01` | `[cmd] READ_NOW` and an immediate new `[read]` |
   | `02 0A 00` | `[cmd] interval 30 s -> 10 s` |
   | `02 05 00` | clamped: stays at 10 s |
   | `10 10 27` and `03` | logged as ignored (no pump) |

6. [ ] Disconnect. Serial shows `[ble] disconnected, reason 0x13, advertising`.
7. [ ] Reset the interval to 30 s: write `02 1E 00`, or just RESET the board.

## 7. The app

Close nRF Connect (a second connection blocks the board) before opening Talking Plant.

1. [ ] Settings → *Real sensor* → *Pair a sensor* → pick `TalkingPlant-XXXX` (it shows
       signal bars).
2. [ ] Connected, firmware 0.1.0, readings "Every 30 s". Serial: `[ble] connected …`,
       `[ble] readings subscribed`, `[cmd] SET_INTERVAL 30 s`, `[cmd] interval 30 s -> 30 s`,
       `[cmd] READ_NOW`, `[read] #n`.
       **Stuck on "Connecting…"** → T16. **"Sensor not compatible"** → T17.
3. [ ] Home chips fill at once. In Settings, the *Raw reading* section (DEBUG) shows soil
       mV, lux, temperature, humidity, flags and sequence: they equal the last `[read]`
       line.
4. [ ] *Read now* → a new `[read]` line appears and the raw section updates.
5. [ ] Range: walk away until the app says "Connecting…", after about 20 s "Sensor
       offline". Come back: Connected again and `SET_INTERVAL` re-sent. Then kill the app
       and relaunch: it reconnects without the picker.
       Disconnect reasons → T14, T15.
6. [ ] Power the board from a USB charger instead of the Mac: readings keep coming.
7. [ ] **Clear sensor history.** Bring-up readings (dry, wet, 0 % and 100 % during
       calibration) pollute the plant's history and mood. Before the overnight run and when
       you've finished calibrating: Settings → *Raw reading* section → *Clear sensor
       history* → *Clear*. Home and History empty out for the real sensor. The simulated
       plant's history is not touched. The button is DEBUG only, sensor mode only.

## 8. Calibration

Settings → *Moisture calibration*. Hold the sensor by its top edge (a hand near the probe
changes the value).

1. [ ] Wipe the sensor dry and hold it in the air → *Capture dry*. Do it three times and
       write the values in table B. They should agree within about 20 mV.
       A "near the top of the board's range" warning means the sensor is on 5V or close
       to the ADC ceiling: check it's on 3V3.
2. [ ] Glass of water, up to the line, top part dry. Wait 30 s. → *Capture wet* three times
       (table B).
3. [ ] *Save calibration*. Status: Calibrated. Home moisture ≈ 100 % in water and ≈ 0 % in
       air. **Always 0 % or 100 % in the pot** → T13.
4. [ ] Real pot: push the sensor in up to the line, about halfway between the stem and the
       edge. Moist soil usually reads 40–80 % (never 100 %: water is the wettest case).
       Note the value, water the plant, *Read now* after a minute: moisture rises. Write
       before and after in table B.
5. [ ] Clear sensor history (step 7.7) so the 0 %/100 % readings don't linger.

**Table B**

| | 1 | 2 | 3 | Average | Serial `[read]` mV (same moment) |
|---|---|---|---|---|---|
| Dry (air) | | | | | |
| Wet (water) | | | | | |

| Pot | Moisture % | Soil mV |
|---|---|---|
| Before watering | | |
| After watering | | |

## 9. End to end, then the overnight run

- [ ] Sensor in air, *Read now*: the plant turns thirsty, the scene and speech bubble change
      in the plant's voice. *Talk* → "how are you?" → it mentions thirst (or the template
      line if Apple Intelligence is off). Back in the pot: mood recovers.
- [ ] Cover the BH1750 for a minute: the mood/scene follows the low light. Uncover it.
- [ ] **Overnight run** at 30 s, logging to a file:

  ```bash
  arduino-cli monitor -p /dev/cu.usbmodemXXXX -c baudrate=115200 | tee bringup-night.log
  ```

  Keep the phone nearby, app open or in the background. In the morning: one `[boot]` line
  only (more → T18), sequence continuous, no disconnect with reason `0x08` (→ T14).

### Testing the app against the test peripheral (when you're not at the board)

The app can also run against the fake sensor on the 13 Pro (see `docs/SETUP.md` section
4). **Keep the test peripheral app in the foreground** on the 13 Pro: iOS advertises
without the local name in the background, so the 17 Pro won't find it. If it isn't found,
bring the test app to the front (it re-advertises on its own) or relaunch it. Never run
the test peripheral at the same time as the real board during step 7.

## 10. Results to bring back (S10)

- [ ] Table A (soil-failure measurements a–d)
- [ ] Table B (dry ×3, wet ×3, pot before/after watering)
- [ ] The module markings from step 1
- [ ] Overnight result (boots seen, sequence continuous?), disconnect reasons seen
- [ ] Anything that needed a fix, and the monitor method that worked best

## 11. Troubleshooting

| # | Symptom | Likely cause | Fix |
|---|---|---|---|
| 1 | No port in `board list` | Charge-only cable; board in a crash loop | Use a data cable; BOOT + RESET download mode, re-flash |
| 2 | Upload: "port busy" / "No serial data received" | Monitor still open; not in download mode | Close the monitor; BOOT + RESET, upload, tap RESET |
| 3 | No log at all | Monitor attached after the boot lines; firmware not running | Use the monitor loop (step 5); wait 30 s for the next `[read]`; re-flash |
| 4 | Board boots without the soil sensor but not with it | A0 = GPIO2 is a strapping pin held at boot | Move AOUT to A1 and change `kSoilPin` (a wiring change: propose a `BLE_CONTRACT.md` update first) |
| 5 | Not advertising (not in nRF Connect) | No `[boot]` line (sketch not running); antenna missing; already connected to another phone (`[ble] connected` in the log); name filter in the scanner | Re-flash; attach the antenna; disconnect the other phone; clear the filter |
| 6 | `[i2c] … missing` | SDA/SCL swapped; no 3V3/GND; loose wire; other address (see `found:`, e.g. BH1750 at 0x5C); no pull-ups | Check wiring one wire at a time; ADDR to GND or change `kLightAddress`; add 4.7 kΩ pull-ups to 3V3 |
| 7 | Probe `ok` but the flag clears later | Intermittent contact | Reseat wires, solder the headers (step 2) |
| 8 | `flags` not `0x07` | Bit 0 soil, bit 1 light, bit 2 env. `0x01` → both I2C missing; `0x03` → AHT20; `0x05` → BH1750 | See T6 |
| 9 | Soil flat ≈ 2500 mV+ in air and water | Saturating: powered from 5V, or NE555 instead of TLC555 | 3V3 only; replace the sensor |
| 10 | Soil ≈ 0 mV | VCC not connected; AOUT not on A0 | Check wiring |
| 11 | Soil changes very slowly after leaving water | Known v1.2 defect: the 1 MΩ discharge resistor isn't connected to GND | Different sensor, or bridge the resistor to GND (only if you're comfortable soldering) |
| 12 | Soil drifts over days | Water reaching the unprotected PCB edge or top electronics | Keep soil below the line; seal the edges (nail polish / heat shrink) |
| 13 | App: moisture always 0 % or 100 % | Not calibrated, or calibrated wrong | Compare the raw soil mV (Settings) with the calibration values; recalibrate |
| 14 | Disconnects, reason `0x08` | Supervision timeout: range, antenna, noisy USB power | Check the antenna, move closer, change the power source |
| 15 | Disconnects, reason `0x13` | The phone closed the link (Forget, mode switch, iOS) | Usually fine |
| 16 | App stuck on "Connecting…" | Stale identifier | The app reconnects by name; else *Forget* and pair again |
| 17 | App: "Sensor not compatible" | Service missing, wrong firmware on the board | Re-flash |
| 18 | Random reboots (`[boot]` again, sequence back to 0) | Brown-out from weak USB power | Other cable, port or charger |

## Sources for the defaults

ESP-IDF ESP32-C3 ADC documentation (12 dB range 0–2500 mV); "Capacitive Soil Moisture
Sensor v1.2" manuals (≈ 2.5 V in air, ≈ 1.0 V in water). The calibration defaults
(2450 / 1050 mV) are replaced with your measured values in S10.
