import Foundation

public enum PlantSpeechText {
    /// Text safe to read aloud. Empty means nothing is spoken.
    public static func clean(_ text: String) -> String {
        let withoutSymbols = removingStageDirections(text).unicodeScalars.filter { scalar in
            !"*_#".unicodeScalars.contains(scalar) && !isEmoji(scalar)
        }
        return String(String.UnicodeScalarView(withoutSymbols))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Keeps the text of `**bold**` and of a single `*word*` inside a sentence, removes headings and list markers,
    /// and puts everything on one line. Other `*…*` are left for `removingStageDirections`.
    static func removingMarkdown(_ text: String) -> String {
        text.replacingOccurrences(of: #"\*\*(.+?)\*\*|__(.+?)__"#, with: "$1$2", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^[ \t]*(?:#{1,6}|[-*•+]|\d+[.)])[ \t]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?<=\w )\*(\w+)\*(?= \w)"#, with: "$1", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Removes `*…*` and `(…)` with their content, e.g. "*sighs* I'm fine (smiling)" becomes "I'm fine".
    static func removingStageDirections(_ text: String) -> String {
        text.replacingOccurrences(of: #"\*[^*]*\*|\([^)]*\)"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func isEmoji(_ scalar: Unicode.Scalar) -> Bool {
        let properties = scalar.properties
        // Digits, # and * carry the emoji property too, so require a presentation form
        // or a code point beyond the basic plane. Joiners and variation selectors go with them.
        return properties.isEmojiPresentation
            || (properties.isEmoji && scalar.value > 0x238C)
            || scalar.value == 0x200D
            || scalar.value == 0xFE0F
    }
}
