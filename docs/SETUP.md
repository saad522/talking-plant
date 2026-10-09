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
arduino-cli core install esp32:esp32
arduino-cli lib install "BH1750" "Adafruit AHTX0" "NimBLE-Arduino"
arduino-cli lib list   # check NimBLE-Arduino is 2.x; its API differs from 1.x
```

Upload once the board arrives:
```bash
arduino-cli board list   # find the port, e.g. /dev/cu.usbmodem1101
arduino-cli upload -p <port> --fqbn esp32:esp32:XIAO_ESP32C3 firmware/talking_plant
```
If the Serial Monitor shows nothing, enable "USB CDC On Boot" for the board.

## 3. Repo and Xcode project
- [ ] Create the folder `talking-plant/`, copy `CLAUDE.md` and `docs/` into it, and run
      `git init`.
- [ ] In Xcode: New Project → iOS App → SwiftUI, name `TalkingPlant`, storage None.
      Save it inside `talking-plant/ios/`. Set the deployment target to iOS 26.
- [ ] Add `NSBluetoothAlwaysUsageDescription` to the target's Info
      (e.g. "Talking Plant connects to your plant sensor over Bluetooth.").
- [ ] Commit, then start Claude Code in `talking-plant/`.
- [ ] After Claude Code creates `ios/PlantKit` in M1: in Xcode, File → Add Package
      Dependencies → Add Local → select `ios/PlantKit`, and link it to the app target.
