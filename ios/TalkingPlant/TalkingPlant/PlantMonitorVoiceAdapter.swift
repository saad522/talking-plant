//
//  PlantMonitorVoiceAdapter.swift
//  TalkingPlant
//

import Foundation
import PlantChat
import PlantMonitor
import PlantShared

/// Sprout's voice on home (docs/plans/P1-alive.md D5).
/// Automatic lines use `.ambient`, so the silent switch mutes them and music keeps playing.
/// A tapped line is an explicit request: `.playback` with ducking, so it is always audible.
@MainActor
struct PlantMonitorVoiceAdapter: PlantMonitorVoice {
    let synthesizer: PlantSynthesizerClient
    let settings: PlantPersonalitySettings

    func speak(_ text: String, mood: PlantMood, trigger: PlantMonitorSpeechTrigger, completion: @escaping () -> Void) {
        let spoken = PlantSpeechText.clean(text)
        guard spoken.isEmpty == false else { return completion() }
        switch trigger {
        case .automatic: PlantHomeAudioSession.activateAmbient()
        case .tap: PlantHomeAudioSession.activatePlayback()
        }
        // The completion also fires when the line is stopped, so music returns to full volume either way.
        synthesizer.speak(spoken, style: settings.load().speechStyle.adjusted(for: mood)) {
            if trigger == .tap {
                PlantHomeAudioSession.deactivate()
            }
            completion()
        }
    }

    func stop() {
        synthesizer.stop()
    }
}
