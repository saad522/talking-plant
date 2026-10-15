import XCTest
@testable import PlantShared

@MainActor
final class GatedPlantSoundEffectsClientTests: PlantSharedXCTestCase {
    func test_init_playsNothing() {
        let (_, decoratee) = makeSUT()

        XCTAssertEqual(decoratee.played, [])
    }

    func test_play_whenEnabledAndVoiceSilent_playsTheEffect() {
        let (sut, decoratee) = makeSUT(isEnabled: true, isVoiceSpeaking: false)

        sut.play(.chime)
        sut.play(.pop)

        XCTAssertEqual(decoratee.played, [.chime, .pop])
    }

    func test_play_whenDisabled_playsNothing() {
        let (sut, decoratee) = makeSUT(isEnabled: false, isVoiceSpeaking: false)

        sut.play(.chime)

        XCTAssertEqual(decoratee.played, [])
    }

    func test_play_whileVoiceSpeaks_playsNothing() {
        let (sut, decoratee) = makeSUT(isEnabled: true, isVoiceSpeaking: true)

        sut.play(.greet)

        XCTAssertEqual(decoratee.played, [])
    }

    func test_play_readsTheGatesAtEveryCall() {
        var isEnabled = true
        let decoratee = SoundEffectsSpy()
        let sut = GatedPlantSoundEffectsClient(decoratee: decoratee, isEnabled: { isEnabled }, isVoiceSpeaking: { false })
        trackMemoryLeak(decoratee)
        trackMemoryLeak(sut)

        isEnabled = false
        sut.play(.chime)
        isEnabled = true
        sut.play(.pop)

        XCTAssertEqual(decoratee.played, [.pop])
    }

    func test_fileNames_areTheBundledSoundNames() {
        XCTAssertEqual(PlantSoundEffect.chime.fileName, "sprout_chime")
        XCTAssertEqual(PlantSoundEffect.pop.fileName, "sprout_pop")
        XCTAssertEqual(PlantSoundEffect.greet.fileName, "sprout_greet")
    }

    // MARK: - Private helpers

    private func makeSUT(
        isEnabled: Bool = true,
        isVoiceSpeaking: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (sut: GatedPlantSoundEffectsClient, decoratee: SoundEffectsSpy) {
        let decoratee = SoundEffectsSpy()
        let sut = GatedPlantSoundEffectsClient(decoratee: decoratee, isEnabled: { isEnabled }, isVoiceSpeaking: { isVoiceSpeaking })
        trackMemoryLeak(decoratee, file: file, line: line)
        trackMemoryLeak(sut, file: file, line: line)
        return (sut, decoratee)
    }

    private final class SoundEffectsSpy: PlantSoundEffectsClient {
        private(set) var played: [PlantSoundEffect] = []
        func play(_ effect: PlantSoundEffect) { played.append(effect) }
    }
}
