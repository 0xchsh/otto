import Foundation
import SwiftData

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

@Model
final class ChatMessage {
    var id: UUID
    var role: MessageRole
    var content: String
    var imageData: [Data]?
    var createdAt: Date
    var session: ChatSession?

    init(role: MessageRole, content: String, imageData: [Data]? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.imageData = imageData
        self.createdAt = Date()
    }
}
