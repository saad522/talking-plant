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
