import XCTest
@testable import PlantChat

final class PlantSpeechChunkerTests: XCTestCase {
    func test_chunks_splitsOnSentenceEndsKeepingPunctuation() {
        XCTAssertEqual(
            PlantSpeechChunker.chunks("The sun feels lovely today. Could I have some water, please? Thank you very much, my friend!"),
            ["The sun feels lovely today.", "Could I have some water, please?", "Thank you very much, my friend!"]
        )
    }

    func test_chunks_splitsAfterEllipsisCharacter() {
        XCTAssertEqual(PlantSpeechChunker.chunks("I am so very thirsty today… Please help me out soon."), ["I am so very thirsty today…", "Please help me out soon."])
    }

    func test_chunks_singleShortSentence_isOneChunk() {
        XCTAssertEqual(PlantSpeechChunker.chunks("Hi."), ["Hi."])
    }

    func test_chunks_textWithoutPunctuation_isOneChunk() {
        XCTAssertEqual(PlantSpeechChunker.chunks("water please"), ["water please"])
    }

    func test_chunks_doesNotSplitDecimals() {
        XCTAssertEqual(
            PlantSpeechChunker.chunks("My soil is at 12.5 percent, which is too dry."),
            ["My soil is at 12.5 percent, which is too dry."]
        )
    }

    func test_chunks_doesNotSplitAbbreviations() {
        XCTAssertEqual(
            PlantSpeechChunker.chunks("Mr. Green says hi, e.g. with a wave. Bye."),
            ["Mr. Green says hi, e.g. with a wave. Bye."]
        )
    }

    func test_chunks_longSentence_splitsAtLastCommaBeforeMaxWords() {
        XCTAssertEqual(
            PlantSpeechChunker.chunks("one two, three four five six; seven eight nine ten.", maxWords: 6),
            ["one two, three four five six;", "seven eight nine ten."]
        )
    }

    func test_chunks_longSentenceWithoutComma_splitsAtMaxWords() {
        XCTAssertEqual(
            PlantSpeechChunker.chunks("one two three four five six seven eight nine.", maxWords: 4),
            ["one two three four", "five six seven eight", "nine."]
        )
    }

    func test_chunks_sentenceAtMaxWords_isNotSplit() {
        XCTAssertEqual(PlantSpeechChunker.chunks("one two, three four.", maxWords: 4), ["one two, three four."])
    }

    func test_chunks_collapsesWhitespace() {
        XCTAssertEqual(PlantSpeechChunker.chunks("  Hi   there.\n\n Bye. "), ["Hi there. Bye."])
    }

    func test_chunks_blankOrEmptyText_givesNoChunks() {
        XCTAssertEqual(PlantSpeechChunker.chunks(""), [])
        XCTAssertEqual(PlantSpeechChunker.chunks(" \n\t "), [])
    }

    func test_chunks_shortSentence_joinsTheNextOne() {
        XCTAssertEqual(PlantSpeechChunker.chunks("Psst... my soil is dry."), ["Psst... my soil is dry."])
        XCTAssertEqual(
            PlantSpeechChunker.chunks("Psst... my soil is getting really dry. Could I have a drink of water, please?"),
            ["Psst... my soil is getting really dry.", "Could I have a drink of water, please?"]
        )
    }

    func test_chunks_shortLastSentence_joinsThePreviousOne() {
        XCTAssertEqual(
            PlantSpeechChunker.chunks("I'm going to fold my leaves. Goodnight!"),
            ["I'm going to fold my leaves. Goodnight!"]
        )
    }

    func test_chunks_merge_neverGoesOverTheCharacterCap() {
        // 41 + 1 + 10 characters would be 52.
        XCTAssertEqual(
            PlantSpeechChunker.chunks("I'm going to fold my leaves and rest now. Goodnight!"),
            ["I'm going to fold my leaves and rest now.", "Goodnight!"]
        )
        XCTAssertEqual(
            PlantSpeechChunker.chunks("Psst... my soil is dry. I'm going to fold my leaves and rest now."),
            ["Psst... my soil is dry.", "I'm going to fold my leaves and rest now."]
        )
    }

    func test_chunks_neverHasMoreThan45CharactersOrTwelveWords_exceptASingleLongWord() {
        let text = "My leaves are drooping and I would like to have a big drink of cold water today, "
            + "because my soil has been dry for days and days. Thank you so much for caring about me, my friend!"

        for chunk in PlantSpeechChunker.chunks(text) {
            XCTAssertLessThanOrEqual(chunk.count, 45, chunk)
            XCTAssertLessThanOrEqual(chunk.split(separator: " ").count, 12, chunk)
        }
        XCTAssertEqual(PlantSpeechChunker.chunks("Supercalifragilisticexpialidocious-and-then-some-more-letters."), ["Supercalifragilisticexpialidocious-and-then-some-more-letters."])
    }

    func test_chunks_longSentenceWithCommas_splitsAtTheLastCommaThatFits() {
        XCTAssertEqual(
            PlantSpeechChunker.chunks("My leaves are drooping a little, and I would love a big drink of water."),
            ["My leaves are drooping a little,", "and I would love a big drink of water."]
        )
    }

    func test_chunks_longSentenceWithDash_splitsAfterTheDash() {
        XCTAssertEqual(
            PlantSpeechChunker.chunks("My leaves are drooping a little — and I would love a big drink of water."),
            ["My leaves are drooping a little —", "and I would love a big drink of water."]
        )
    }

    func test_chunks_longSentenceWithoutCommas_splitsAtAWordBoundary() {
        XCTAssertEqual(
            PlantSpeechChunker.chunks("My leaves are drooping and I would really love a big drink of cold water today."),
            ["My leaves are drooping and I would really", "love a big drink of cold water today."]
        )
    }

    func test_chunks_wordBoundarySplit_doesNotEndOnAShortWord() {
        XCTAssertEqual(
            PlantSpeechChunker.chunks("My leaves are drooping and I would like to have a big drink of cold water today."),
            ["My leaves are drooping and I would like", "to have a big drink of cold water today."]
        )
    }

    func test_chunks_commaThatLeavesATinyPiece_isSkippedForAWordBoundary() {
        XCTAssertEqual(
            PlantSpeechChunker.chunks("Oh my, I have been feeling quite thirsty lately and need water."),
            ["Oh my, I have been feeling quite thirsty", "lately and need water."]
        )
    }

    func test_chunks_overTwelveShortWords_splitsAtTwelve() {
        XCTAssertEqual(
            PlantSpeechChunker.chunks("ab cd ef gh ij kl mn op qr st uv wx yz."),
            ["ab cd ef gh ij kl mn op qr st uv wx", "yz."]
        )
    }

    #if DEBUG
    @MainActor
    func test_voiceCheckSample_hasAChunkNearTheCap() {
        let chunks = PlantSpeechChunker.chunks(PlantVoiceCheckViewModel.sampleSentence)

        XCTAssertGreaterThanOrEqual(chunks.count, 3)
        XCTAssertGreaterThanOrEqual(chunks.map(\.count).max() ?? 0, 40)
        XCTAssertLessThanOrEqual(chunks.map(\.count).max() ?? 0, 45)
    }
    #endif

    func test_chunks_shortChunk_doesNotJoinWhenOverMaxWords() {
        XCTAssertEqual(PlantSpeechChunker.chunks("Hi. Yes. Ok.", maxWords: 2), ["Hi. Yes.", "Ok."])
        XCTAssertEqual(PlantSpeechChunker.chunks("Hi. Yes. Ok.", maxWords: 1), ["Hi.", "Yes.", "Ok."])
    }
}
