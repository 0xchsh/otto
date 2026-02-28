import Foundation
import SwiftData

@Model
final class Vehicle {
    var id: UUID
    var vin: String?
    var make: String
    var model: String
    var year: Int
    var trim: String?
    var nickname: String?
    var isActive: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ChatSession.vehicle)
    var sessions: [ChatSession]

    var topBarName: String {
        nickname ?? make
    }

    var displayName: String {
        "\(year) \(make) \(model)"
    }

    var fullDisplayName: String {
        if let trim {
            return "\(year) \(make) \(model) \(trim)"
        }
        return displayName
    }

    init(make: String, model: String, year: Int, vin: String? = nil, trim: String? = nil, nickname: String? = nil) {
        self.id = UUID()
        self.make = make
        self.model = model
        self.year = year
        self.vin = vin
        self.trim = trim
        self.nickname = nickname
        self.isActive = true
        self.createdAt = Date()
        self.sessions = []
    }
}
