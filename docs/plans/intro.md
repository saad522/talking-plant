# Animated intro

A cold-launch intro that continues the static launch screen, then hands off to home.

## Plan

1. Replace `LaunchSprout.imageset` (the old image clipped the right leaf) and add `LaunchSproutBlink.imageset` (same size and framing, eyes closed).
2. `PlantIntro` (business, no SwiftUI): `PlantIntroViewModel` state machine (ready, playing, handingOff, finished; skip, reduce motion, completion), `PlantIntroLaunchTracker` (cold vs warm), `PlantIntroGreeting` (pure `greeting(for hour:)`), `PlantIntroTimeline` (pure pose, blink, glow, text curves) and `PlantIntroParticle`. Strings in `Resources/en.lproj/PlantIntro.strings`.
3. `PlantIntroiOS` (thin views): `PlantIntroView` and `PlantIntroUIComposer`. One `TimelineView` feeds elapsed time to the pure `PlantIntroTimeline` functions.
4. `PlantMonitorUIComposer.background(for:)`: one small public function returning the home background colour for a scene.
5. `TalkingPlantApp`: one tracker per process, the intro as an overlay above the home view, which is built underneath from the start.

## Timeline (2.2 s)

- 0.0-0.5 s: squash-and-stretch bounce, leaf wiggle, one blink (swap to `LaunchSproutBlink` for 120 ms), soft haptic.
- 0.2-1.0 s: glow pulses once behind Sprout. 15 particles drift up over 0.2-1.6 s (fireflies from 18:00 to 04:59, pollen by day).
- 0.4-1.0 s: "Sprout" and the greeting rise and fade in. 5-11 morning, 12-17 afternoon, 18-22 evening, 23-4 "Shh... sweet dreams".
- 1.0-1.6 s: the text is held fully visible.
- 1.6-2.2 s: hand-off.
- Tap anywhere skips to a 0.3 s hand-off. Reduce Motion: no movement, just a 0.3 s crossfade.

## Decisions

- Strings live in the feature (`PlantIntro.strings`), like the other features.
- Home palette: the app passes the home background colour for the remembered last scene into the intro. The intro never imports `PlantMonitor`.
- Blink uses the supplied closed-eyes image, not hand-drawn eyelids. The app passes both images in.
- Frame 0: `LaunchBackground` full screen, the image at its natural size centred in the safe-area region (`UIImageRespectsSafeAreaInsets = true`). Verified on device by the human.
- Hand-off: scale + offset + fade of the intro Sprout and a crossfade of the background; no `matchedGeometryEffect`.
- The cold-launch flag is created once per process in `TalkingPlantApp`; returning from background never replays the intro.
