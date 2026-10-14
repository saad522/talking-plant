import KokoroSpike
import XCTest

final class KokoroSpikeSentencesTests: XCTestCase {
    func test_chunks_splitsOnSentenceEnds() {
        XCTAssertEqual(
            KokoroSpikeSentences.chunks("The sun feels lovely today. Could I have some water, please? Thank you very much, my friend!"),
            ["The sun feels lovely today.", "Could I have some water, please?", "Thank you very much, my friend!"]
        )
    }

    func test_chunks_joinsShortSentenceWithTheNextOne() {
        XCTAssertEqual(
            KokoroSpikeSentences.chunks("Psst... my soil is getting really dry. Could I have a drink of water, please?"),
            ["Psst... my soil is getting really dry.", "Could I have a drink of water, please?"]
        )
    }

    func test_chunks_joinsShortLastSentenceWithThePreviousOne() {
        XCTAssertEqual(
            KokoroSpikeSentences.chunks("I'm going to fold my leaves and rest now. Goodnight!"),
            ["I'm going to fold my leaves and rest now. Goodnight!"]
        )
    }

    func test_chunks_keepsAShortTextWhole() {
        XCTAssertEqual(KokoroSpikeSentences.chunks("  Hi!  "), ["Hi!"])
    }

    func test_chunks_doesNotSplitInsideNumbers() {
        XCTAssertEqual(
            KokoroSpikeSentences.chunks("My soil is at 12.5 percent, which is too dry."),
            ["My soil is at 12.5 percent, which is too dry."]
        )
    }

    func test_chunks_returnsNothingForBlankText() {
        XCTAssertEqual(KokoroSpikeSentences.chunks(" \n "), [])
    }

    func test_everyLine_startsWithAChunkShorterThanTheWholeLine() {
        for line in KokoroSpikeLine.allCases {
            XCTAssertGreaterThan(KokoroSpikeSentences.chunks(line.text).count, 1, "\(line)")
        }
    }
}
