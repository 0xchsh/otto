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
    var exteriorColor: String?
    var isActive: Bool
    var createdAt: Date

    // Cached API data (persisted so we don't re-fetch)
    var cachedOwnerManualURL: String?
    var cachedMaintenanceJSON: String?
    var cachedRecallsJSON: String?
    var cachedWarrantyJSON: String?
    var vehicleDataLastFetched: Date?

    /// Complete vehicle profile document fed to the LLM as context.
    /// Generated once from vehicle details + API data, then cached.
    var cachedProfileDocument: String?

    @Relationship(deleteRule: .cascade, inverse: \ChatSession.vehicle)
    var sessions: [ChatSession]

    var imageURL: URL? {
        var components = URLComponents(string: "https://cdn.imagin.studio/getimage")!
        var items = [
            URLQueryItem(name: "customer", value: "hrjavascript-masede"),
            URLQueryItem(name: "make", value: make),
            URLQueryItem(name: "modelFamily", value: model),
            URLQueryItem(name: "modelYear", value: "\(year)"),
            URLQueryItem(name: "angle", value: "5")
        ]
        if let exteriorColor, !exteriorColor.isEmpty {
            items.append(URLQueryItem(name: "paintDescription", value: exteriorColor))
        }
        components.queryItems = items
        return components.url
    }

    var topBarName: String {
        if let nickname, !nickname.isEmpty { return nickname }
        if !make.isEmpty { return make }
        return "My Vehicle"
    }

    var displayName: String {
        let parts = [String(year), make, model].filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    var fullDisplayName: String {
        if let trim {
            return "\(year) \(make) \(model) \(trim)"
        }
        return displayName
    }

    init(make: String, model: String, year: Int, vin: String? = nil, trim: String? = nil, nickname: String? = nil, exteriorColor: String? = nil) {
        self.id = UUID()
        self.make = make
        self.model = model
        self.year = year
        self.vin = vin
        self.trim = trim
        self.nickname = nickname
        self.exteriorColor = exteriorColor
        self.isActive = true
        self.createdAt = Date()
        self.sessions = []
    }
}
