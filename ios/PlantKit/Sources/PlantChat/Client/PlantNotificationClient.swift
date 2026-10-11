import Foundation

@MainActor
public protocol PlantNotificationClient {
    func post(title: String, body: String)
}
