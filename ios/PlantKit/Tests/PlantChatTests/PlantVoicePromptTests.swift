import PlantShared
import XCTest
@testable import PlantChat

@MainActor
final class PlantVoicePromptTests: PlantChatXCTestCase {
    // MARK: - instructions

    func test_instructions_includeNameAndVoiceOfEveryPersonality() {
        PlantPersonality.allCases.forEach { personality in
            let text = PlantVoicePrompt.instructions(personality: personality, plantName: "Sprout")

            XCTAssertTrue(text.contains("You are Sprout"), "\(personality)")
            XCTAssertTrue(text.contains(personality.voice), "\(personality)")
        }
    }

    func test_instructions_differBetweenPersonalities() {
        let texts = PlantPersonality.allCases.map { PlantVoicePrompt.instructions(personality: $0, plantName: "Sprout") }

        XCTAssertEqual(Set(texts).count, PlantPersonality.allCases.count)
    }

    func test_instructions_askForShortAnswersAndNoGuessedNumbers() {
        let text = PlantVoicePrompt.instructions(personality: .cheerful, plantName: "Sprout")

        XCTAssertTrue(text.contains("1–3 short sentences"))
        XCTAssertTrue(text.contains("Only use numbers that appear in the facts or in a tool result"))
        XCTAssertTrue(text.contains("never guess a value"))
        XCTAssertTrue(text.contains("If you don't know, say so"))
    }

    // MARK: - facts

    func test_facts_describesEveryMood() {
        let descriptions = PlantMood.allCases.map { PlantVoicePrompt.facts(makeFacts(mood: $0)).components(separatedBy: "\n")[0] }

        XCTAssertEqual(Set(descriptions).count, PlantMood.allCases.count)
        XCTAssertEqual(
            PlantVoicePrompt.facts(makeFacts(mood: .thirsty)).components(separatedBy: "\n")[0],
            "Mood: thirsty: your SOIL is dry (this is about water in the pot, not the air), you'd like water soon"
        )
    }

    func test_facts_formatsEveryReadingValue() {
        let text = PlantVoicePrompt.facts(makeFacts(reading: makeReading(moisture: 24.4, lux: 1_200, temperature: 21.04, humidity: 55.2)))

        XCTAssertTrue(text.contains("Moisture: 24%"))
        XCTAssertTrue(text.contains("Light: 1,200 lx"))
        XCTAssertTrue(text.contains("Temperature: 21.0 °C"))
        XCTAssertTrue(text.contains("Humidity: 55%"))
        XCTAssertFalse(text.contains("No readings yet."))
    }

    func test_facts_leavesOutNilValues() {
        let text = PlantVoicePrompt.facts(makeFacts(reading: makeReading(moisture: nil, lux: 10, temperature: nil, humidity: nil)))

        XCTAssertTrue(text.contains("Light: 10 lx"))
        XCTAssertFalse(text.contains("Moisture:"))
        XCTAssertFalse(text.contains("Temperature:"))
        XCTAssertFalse(text.contains("Humidity:"))
    }

    func test_facts_saysNoReadingsWithoutReading() {
        let facts = PlantVoiceFacts(mood: .offline, isSleeping: false, reading: nil)

        XCTAssertTrue(PlantVoicePrompt.facts(facts).hasSuffix("\nNo readings yet."))
    }

    func test_facts_mentionsNightWhenSleeping() {
        XCTAssertTrue(PlantVoicePrompt.facts(makeFacts(mood: .happy, isSleeping: true)).contains("It's night and you're sleepy."))
        XCTAssertFalse(PlantVoicePrompt.facts(makeFacts(mood: .happy, isSleeping: false)).contains("sleepy"))
    }

    func test_facts_saysEverySensorWithoutProblemIsFine() {
        let text = PlantVoicePrompt.facts(makeFacts(mood: .happy))

        XCTAssertTrue(text.contains("Your soil moisture is fine: you do NOT need water."))
        XCTAssertTrue(text.contains("Your light is fine: you do NOT need more light."))
        XCTAssertTrue(text.contains("Your temperature is fine: you are NOT too hot or too cold."))
        XCTAssertTrue(text.contains("The air humidity is fine: the air is NOT too dry."))
    }

    func test_facts_leavesOutNegativeOfSensorWithProblem() {
        let cases: [(PlantMood, String)] = [
            (.thirsty, "soil moisture is fine"), (.veryThirsty, "soil moisture is fine"), (.drowning, "soil moisture is fine"),
            (.tooDark, "light is fine"), (.tooHot, "temperature is fine"), (.tooCold, "temperature is fine"),
            (.dryAir, "humidity is fine")
        ]

        cases.forEach { mood, negative in
            let text = PlantVoicePrompt.facts(makeFacts(mood: mood))

            XCTAssertFalse(text.contains(negative), "\(mood)")
            XCTAssertEqual(text.components(separatedBy: "fine:").count - 1, 3, "\(mood)")
        }
    }

    func test_facts_leavesOutNegativesOfEveryCurrentProblem() {
        let text = PlantVoicePrompt.facts(makeFacts(mood: .tooHot, problems: [.tooHot, .thirsty]))

        XCTAssertFalse(text.contains("soil moisture is fine"))
        XCTAssertFalse(text.contains("temperature is fine"))
        XCTAssertFalse(text.contains("you do NOT need water"))
        XCTAssertTrue(text.contains("light is fine"))
        XCTAssertTrue(text.contains("humidity is fine"))
    }

    func test_facts_leavesOutNegativeOfSensorWithoutValue() {
        let text = PlantVoicePrompt.facts(makeFacts(mood: .happy, reading: makeReading(moisture: nil, humidity: nil)))

        XCTAssertFalse(text.contains("soil moisture is fine"))
        XCTAssertFalse(text.contains("humidity is fine"))
        XCTAssertTrue(text.contains("light is fine"))
    }

    func test_facts_keepsDrySoilAndDryAirApart() {
        let soil = PlantVoicePrompt.facts(makeFacts(mood: .thirsty))
        let air = PlantVoicePrompt.facts(makeFacts(mood: .dryAir))

        XCTAssertTrue(soil.contains("your SOIL is dry (this is about water in the pot, not the air)"))
        XCTAssertTrue(air.contains("the AIR in the room is dry (this is about humidity, not your soil; you do NOT need water)"))
    }

    func test_facts_mentionsRecentWateringOnlyWhenSet() {
        XCTAssertTrue(PlantVoicePrompt.facts(makeFacts(mood: .happy, wateredMinutesAgo: 12)).contains("You were watered 12 minutes ago."))
        XCTAssertTrue(PlantVoicePrompt.facts(makeFacts(mood: .happy, wateredMinutesAgo: 1)).contains("You were watered 1 minute ago."))
        XCTAssertFalse(PlantVoicePrompt.facts(makeFacts(mood: .happy)).contains("watered"))
    }

    // MARK: - message

    func test_message_putsCurrentFactsBeforeText() {
        let facts = makeFacts()

        XCTAssertEqual(
            PlantVoicePrompt.message("How are you?", facts: facts),
            "Right now (always trust this over anything said earlier in the conversation):\n\(PlantVoicePrompt.facts(facts))\n\nThe person says: How are you?"
        )
    }

    // MARK: - line

    func test_line_asksForShortLineWithoutNumbersForEveryPurpose() {
        let facts = makeFacts()
        let purposes: [PlantVoiceLineRequest.Purpose] = [.home, .notification, .greeting]

        let texts = purposes.map { PlantVoicePrompt.line(facts, purpose: $0) }

        texts.forEach { text in
            XCTAssertTrue(text.contains(", with no numbers"))
            XCTAssertTrue(text.contains(PlantVoicePrompt.facts(facts)))
        }
        XCTAssertEqual(Set(texts).count, purposes.count)
    }

    func test_line_givesHomeAndNotificationTheirRules() {
        [PlantVoiceLineRequest.Purpose.home, .notification].forEach { purpose in
            let text = PlantVoicePrompt.line(makeFacts(), purpose: purpose)

            XCTAssertTrue(text.contains("at most 10 words, with no numbers"), "\(purpose)")
            XCTAssertTrue(text.contains("Speak as the plant, in the first person."), "\(purpose)")
            XCTAssertTrue(text.contains("Never say \"your plant\"."), "\(purpose)")
            XCTAssertTrue(text.contains("Never thank or reply to the person."), "\(purpose)")
        }
    }

    func test_line_soundsSleepyOnlyWhenSleeping() {
        [PlantVoiceLineRequest.Purpose.home, .notification].forEach { purpose in
            XCTAssertTrue(PlantVoicePrompt.line(makeFacts(mood: .happy, isSleeping: true), purpose: purpose).contains("Sound sleepy."))
            XCTAssertFalse(PlantVoicePrompt.line(makeFacts(mood: .happy, isSleeping: false), purpose: purpose).contains("sleepy."))
        }
    }

    func test_line_keepsGreetingToTwelveWordsWithoutTenWordRule() {
        let text = PlantVoicePrompt.line(makeFacts(), purpose: .greeting)

        XCTAssertTrue(text.contains("at most 12 words, with no numbers"))
        XCTAssertFalse(text.contains("10 words"))
        XCTAssertFalse(text.contains("Sound sleepy."))
    }

    // MARK: - history

    func test_history_writesStatisticsWithFormatter() {
        let summary = PlantHistorySummary(
            period: .day,
            readingCount: 3,
            moisture: .init(minimum: 20.2, average: 35, maximum: 50),
            lux: .init(minimum: 0, average: 1_000.4, maximum: 20_000),
            temperature: .init(minimum: 18, average: 21.5, maximum: 25),
            humidity: .init(minimum: 40, average: 50, maximum: 60)
        )

        XCTAssertEqual(PlantVoicePrompt.history(summary), """
        Last 24 hours (3 readings):
        Moisture: min 20%, average 35%, max 50%
        Light: min 0 lx, average 1,000 lx, max 20,000 lx
        Temperature: min 18.0 °C, average 21.5 °C, max 25.0 °C
        Humidity: min 40%, average 50%, max 60%
        """)
    }

    func test_history_leavesOutSensorsWithoutValuesAndNamesWeek() {
        let summary = PlantHistorySummary(
            period: .week,
            readingCount: 2,
            moisture: .init(minimum: 10, average: 15, maximum: 20),
            lux: nil,
            temperature: nil,
            humidity: nil
        )

        XCTAssertEqual(PlantVoicePrompt.history(summary), "Last 7 days (2 readings):\nMoisture: min 10%, average 15%, max 20%")
    }

    func test_history_saysNoReadingsForEmptyHistory() {
        let summary = PlantHistorySummary(period: .week, readingCount: 0, moisture: nil, lux: nil, temperature: nil, humidity: nil)

        XCTAssertEqual(PlantVoicePrompt.history(summary), "Last 7 days: no readings.")
    }

    // MARK: - cleanLine

    func test_cleanLine_deliversPlainLine() {
        XCTAssertEqual(PlantVoicePrompt.cleanLine("I could use a drink."), "I could use a drink.")
    }

    func test_cleanLine_trimsWhitespace() {
        XCTAssertEqual(PlantVoicePrompt.cleanLine("  \n Hello there \n "), "Hello there")
    }

    func test_cleanLine_removesSurroundingQuotes() {
        XCTAssertEqual(PlantVoicePrompt.cleanLine("\"Water me, please!\""), "Water me, please!")
        XCTAssertEqual(PlantVoicePrompt.cleanLine("“Water me, please!”"), "Water me, please!")
        XCTAssertEqual(PlantVoicePrompt.cleanLine(" ' Water me ' "), "Water me")
    }

    func test_cleanLine_keepsQuotesInsideTheLine() {
        XCTAssertEqual(PlantVoicePrompt.cleanLine("I'm \"thirsty\" today"), "I'm \"thirsty\" today")
    }

    func test_cleanLine_keepsFirstLineOnly() {
        XCTAssertEqual(PlantVoicePrompt.cleanLine("First line.\nSecond line."), "First line.")
        XCTAssertEqual(PlantVoicePrompt.cleanLine("\n\nFirst line.\r\nSecond line."), "First line.")
    }

    func test_cleanLine_deliversNilForEmptyResult() {
        XCTAssertNil(PlantVoicePrompt.cleanLine(""))
        XCTAssertNil(PlantVoicePrompt.cleanLine("  \n  "))
        XCTAssertNil(PlantVoicePrompt.cleanLine("\"\""))
    }

    func test_cleanLine_deliversNilForLongLine() {
        XCTAssertNotNil(PlantVoicePrompt.cleanLine(String(repeating: "a", count: 70)))
        XCTAssertNil(PlantVoicePrompt.cleanLine(String(repeating: "a", count: 71)))
    }

    func test_cleanLine_deliversNilForMoreThanTwelveWords() {
        XCTAssertNotNil(PlantVoicePrompt.cleanLine("one two three four five six seven eight nine ten eleven twelve"))
        XCTAssertNil(PlantVoicePrompt.cleanLine("one two three four five six seven eight nine ten eleven twelve thirteen"))
    }

    func test_cleanLine_deliversNilWhenLineSaysYourPlant() {
        XCTAssertNil(PlantVoicePrompt.cleanLine("Thanks for caring for your plant"))
        XCTAssertNil(PlantVoicePrompt.cleanLine("Your Plant is happy"))
    }

    func test_cleanLine_deliversNilWhenLineContainsDigit() {
        XCTAssertNil(PlantVoicePrompt.cleanLine("I am at 24% moisture"))
        XCTAssertNil(PlantVoicePrompt.cleanLine("Day 1 of my new life"))
    }

    func test_cleanLine_ignoresDigitsOnLaterLines() {
        XCTAssertEqual(PlantVoicePrompt.cleanLine("Hello!\nMoisture is 24%"), "Hello!")
    }
}
