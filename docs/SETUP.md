# Setup (manual steps for the human)

## 1. Mac and iPhone
- [ ] Latest Xcode with the iOS 26 SDK.
- [ ] Claude Code installed and signed in.
- [ ] iPhone that supports Apple Intelligence, with Apple Intelligence turned on
      (needed for Foundation Models).
- [ ] Homebrew installed.

## 2. Arduino toolchain
Arduino IDE 2 is optional (nice for the Serial Monitor). `arduino-cli` lets Claude Code
compile and upload from the terminal.

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
USB CDC On Boot is already enabled by default for this board in core 3.3.12. Logs printed
before the monitor attaches are lost, so press RESET after opening it. If the port
disappears (crashing sketch), hold BOOT while plugging in USB, then upload.

## 3. Repo and Xcode project
- [ ] Create the folder `talking-plant/`, copy `CLAUDE.md` and `docs/` into it, and run
      `git init`.
- [ ] In Xcode: New Project → iOS App → SwiftUI, name `TalkingPlant`, storage None.
      Save it inside `talking-plant/ios/`. Set the deployment target to iOS 26.
- [ ] Add `NSBluetoothAlwaysUsageDescription` to the target's Info
      (e.g. "Talking Plant connects to your plant sensor over Bluetooth.").
- [ ] Commit, then start Claude Code in `talking-plant/`.
- [ ] After Claude Code creates `ios/PlantKit` in M1: in Xcode, File → Add Package
      Dependencies → Add Local → select `ios/PlantKit`, and link the `PlantShared`,
      `PlantMonitor`, `PlantMonitoriOS`, and `PlantDevice` products to the app target.

## 4. Test peripheral (a fake sensor, no board needed)

The app can pretend to be the sensor, so the real Bluetooth path runs before the board
arrives. DEBUG builds only. You need two Bluetooth devices: the phone that runs the app
normally, and a second iPhone/iPad (or this Mac, with the *Mac (Designed for iPad)*
destination turned on) that plays the sensor.

- [ ] On the second device, run the app from Xcode with the launch argument
      `-PlantTestPeripheral` (Edit Scheme → Run → Arguments, tick it). Accept the Bluetooth
      prompt. The screen shows the state, the interval, the last commands, and a Water button.
      It advertises as `TalkingPlant-TEST`.
- [ ] On the main iPhone, run the app without that argument. Settings → *Real sensor* →
      pair `TalkingPlant-TEST`. The test device logs `SET_INTERVAL`, then `READ_NOW`.
- [ ] Optional: `-PlantReadingInterval 30` on the main iPhone sets the reading interval to
      30 s (the default is 300 s). Tick it in the scheme; an unticked entry is ignored.
- [ ] If the pairing stops working after Bluetooth was toggled on the test device, tap
      *Forget* and pair again: Apple devices change their identifier.
- [ ] Keep the test peripheral app in the foreground. iOS advertises without the local name
      in the background, so the main iPhone won't find it. If it isn't found, bring the test
      app to the front (it re-advertises on its own) or relaunch it.

The checklist to run is section 9 of `docs/plans/M6-bluetooth.md`.
