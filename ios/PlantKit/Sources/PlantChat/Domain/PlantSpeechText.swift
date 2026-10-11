import Foundation

public enum PlantSpeechText {
    /// Text safe to read aloud. Empty means nothing is spoken.
    public static func clean(_ text: String) -> String {
        let withoutSymbols = text.unicodeScalars.filter { scalar in
            !"*_#".unicodeScalars.contains(scalar) && !isEmoji(scalar)
        }
        return String(String.UnicodeScalarView(withoutSymbols))
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
