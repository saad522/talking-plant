import Foundation

public struct PlantChatMessageViewModel: Equatable, Identifiable, Sendable {
    public enum Sender: Equatable, Sendable {
        case plant
        case user
    }

    public let id: Int
    public let text: String
    public let sender: Sender

    public init(id: Int, text: String, sender: Sender) {
        self.id = id
        self.text = text
        self.sender = sender
    }
}
