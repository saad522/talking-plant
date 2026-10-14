import Foundation

/// A Kokoro voice pack, named like the files in `voices.npz` ("af_heart").
public struct KokoroSpikeVoice: Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let label: String

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }

    /// `b…` voices are British English, `a…` voices American English.
    public var isBritish: Bool { id.hasPrefix("b") }

    /// A handful of English voices. Grades are from hexgrad/Kokoro-82M VOICES.md.
    public static let catalog: [KokoroSpikeVoice] = [
        KokoroSpikeVoice(id: "af_heart", label: "Heart · US F · A"),
        KokoroSpikeVoice(id: "af_bella", label: "Bella · US F · A-"),
        KokoroSpikeVoice(id: "af_nicole", label: "Nicole · US F · B-"),
        KokoroSpikeVoice(id: "af_sky", label: "Sky · US F · C-"),
        KokoroSpikeVoice(id: "am_puck", label: "Puck · US M · C+"),
        KokoroSpikeVoice(id: "am_fenrir", label: "Fenrir · US M · C+"),
        KokoroSpikeVoice(id: "am_michael", label: "Michael · US M · C+"),
        KokoroSpikeVoice(id: "bf_emma", label: "Emma · GB F · B-"),
        KokoroSpikeVoice(id: "bm_fable", label: "Fable · GB M · C")
    ]
}
