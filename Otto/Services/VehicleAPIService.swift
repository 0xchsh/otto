import Foundation

enum VehicleAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code): return "HTTP error: \(code)"
        case .decodingError: return "Failed to decode response"
        case .noData: return "No data received"
        }
    }
}

// MARK: - API Response Types

struct OwnerManualResponse: Codable {
    let status: String
    let data: OwnerManualData?

    struct OwnerManualData: Codable {
        let path: String?
    }
}

struct MaintenanceItem: Codable {
    let mileage: Mileage?
    let service_items: [String]?

    struct Mileage: Codable {
        let miles: Int?
        let km: Int?
    }
}

struct MaintenanceResponse: Codable {
    let status: String
    let data: MaintenanceData?

    struct MaintenanceData: Codable {
        let maintenance: [MaintenanceItem]?
    }
}

struct RecallItem: Codable {
    let campaign_id: String?
    let recall_date: String?
    let component_affected: String?
    let summary: String?
    let consequences: String?
    let remedy: String?
}

struct RecallsResponse: Codable {
    let status: String
    let data: RecallsData?

    struct RecallsData: Codable {
        let recall: [RecallItem]?
    }
}

struct WarrantyResponse: Codable {
    let status: String
    let data: WarrantyData?

    struct WarrantyData: Codable {
        let warranty: [String: String]?
    }
}

// MARK: - Vehicle Context (for system prompt)

struct VehicleContext {
    var ownerManualURL: String?
    var maintenance: [MaintenanceItem]?
    var recalls: [RecallItem]?
    var warranty: [String: String]?

    /// Build a complete vehicle profile document from vehicle info + API data.
    /// This is the single context file the LLM receives for every message.
    static func buildProfileDocument(
        nickname: String?,
        year: Int,
        make: String,
        model: String,
        trim: String?,
        vin: String?,
        apiData: VehicleContext
    ) -> String {
        var doc = """
        VEHICLE PROFILE
        ===============
        Name: \(nickname ?? make)
        Year: \(year)
        Make: \(make)
        Model: \(model)
        """

        if let trim, !trim.isEmpty { doc += "\nTrim: \(trim)" }
        if let vin, !vin.isEmpty { doc += "\nVIN: \(vin)" }

        // Owner's manual
        if let url = apiData.ownerManualURL {
            doc += "\n\nOWNER'S MANUAL\n--------------\nPDF: \(url)"
        }

        // Warranty
        if let warranty = apiData.warranty, !warranty.isEmpty {
            doc += "\n\nWARRANTY COVERAGE\n-----------------"
            for (key, value) in warranty.sorted(by: { $0.key < $1.key }) {
                let label = key.replacingOccurrences(of: "Warranty - ", with: "")
                doc += "\n\(label): \(value)"
            }
        }

        // Recalls
        if let recalls = apiData.recalls, !recalls.isEmpty {
            doc += "\n\nACTIVE RECALLS (\(recalls.count))\n--------------------"
            for recall in recalls.prefix(8) {
                if let component = recall.component_affected {
                    doc += "\n\nComponent: \(component)"
                }
                if let date = recall.recall_date {
                    doc += "\nDate: \(date)"
                }
                if let id = recall.campaign_id {
                    doc += "\nCampaign: \(id)"
                }
                if let summary = recall.summary {
                    let short = summary.count > 300 ? String(summary.prefix(300)) + "..." : summary
                    doc += "\nSummary: \(short)"
                }
                if let remedy = recall.remedy {
                    let short = remedy.count > 200 ? String(remedy.prefix(200)) + "..." : remedy
                    doc += "\nRemedy: \(short)"
                }
            }
        }

        // Maintenance schedule
        if let maintenance = apiData.maintenance, !maintenance.isEmpty {
            doc += "\n\nOEM MAINTENANCE SCHEDULE\n------------------------"
            for item in maintenance {
                guard let miles = item.mileage?.miles, let services = item.service_items else { continue }
                doc += "\n\(miles.formatted()) miles:"
                for service in services {
                    doc += "\n  - \(service)"
                }
            }
        }

        return doc
    }
}

// MARK: - Service

actor VehicleAPIService {
    static let apiKeyKeychainKey = "vehicle_api_key"
    private let baseURL = "https://api.vehicledatabases.com"
    private let session: URLSession
    private let supabase = SupabaseService()

    init(session: URLSession = .shared) {
        self.session = session
    }

    private var apiKey: String? {
        // User-provided key takes priority, then fall back to bundled Secrets.plist
        if let keychainKey = KeychainService.load(key: VehicleAPIService.apiKeyKeychainKey) {
            return keychainKey
        }
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let key = dict["VEHICLE_DATABASES_API_KEY"] as? String,
           !key.isEmpty {
            return key
        }
        return nil
    }

    func fetchVehicleContext(vin: String?, year: Int, make: String, model: String) async -> VehicleContext {
        var context = VehicleContext()

        if let vin, !vin.isEmpty {
            context.ownerManualURL = try? await fetchOwnerManual(vin: vin)
            context.maintenance = try? await fetchMaintenance(vin: vin)
            context.recalls = try? await fetchRecalls(vin: vin)
        }

        context.warranty = try? await fetchWarranty(year: year, make: make, model: model)

        return context
    }

    func fetchOwnerManual(vin: String) async throws -> String? {
        let cacheKey = vin
        let endpoint = "owner_manual"

        // Check Supabase cache first
        if let cached = await supabase.fetchCachedVehicleData(cacheKey: cacheKey, endpoint: endpoint) {
            let response = try? JSONDecoder().decode(OwnerManualResponse.self, from: cached)
            if let response { return response.data?.path }
        }

        // Cache miss — fetch from API
        let url = try buildURL(path: "/owner-manual/\(vin)")
        let data = try await performRequest(url: url)
        let response = try JSONDecoder().decode(OwnerManualResponse.self, from: data)

        // Store in Supabase (fire-and-forget)
        await supabase.storeCachedVehicleData(cacheKey: cacheKey, endpoint: endpoint, json: data)

        return response.data?.path
    }

    func fetchMaintenance(vin: String) async throws -> [MaintenanceItem] {
        let cacheKey = vin
        let endpoint = "maintenance"

        if let cached = await supabase.fetchCachedVehicleData(cacheKey: cacheKey, endpoint: endpoint) {
            let response = try? JSONDecoder().decode(MaintenanceResponse.self, from: cached)
            if let response { return response.data?.maintenance ?? [] }
        }

        let url = try buildURL(path: "/vehicle-maintenance/v4/\(vin)")
        let data = try await performRequest(url: url)
        let response = try JSONDecoder().decode(MaintenanceResponse.self, from: data)

        await supabase.storeCachedVehicleData(cacheKey: cacheKey, endpoint: endpoint, json: data)

        return response.data?.maintenance ?? []
    }

    func fetchRecalls(vin: String) async throws -> [RecallItem] {
        let cacheKey = vin
        let endpoint = "recalls"

        // Recalls use 30-day expiry (handled inside SupabaseService)
        if let cached = await supabase.fetchCachedVehicleData(cacheKey: cacheKey, endpoint: endpoint) {
            let response = try? JSONDecoder().decode(RecallsResponse.self, from: cached)
            if let response { return response.data?.recall ?? [] }
        }

        let url = try buildURL(path: "/vehicle-recalls/\(vin)")
        let data = try await performRequest(url: url)
        let response = try JSONDecoder().decode(RecallsResponse.self, from: data)

        await supabase.storeCachedVehicleData(cacheKey: cacheKey, endpoint: endpoint, json: data)

        return response.data?.recall ?? []
    }

    func fetchWarranty(year: Int, make: String, model: String) async throws -> [String: String] {
        let cacheKey = "\(year)/\(make)/\(model)"
        let endpoint = "warranty"

        if let cached = await supabase.fetchCachedVehicleData(cacheKey: cacheKey, endpoint: endpoint) {
            let response = try? JSONDecoder().decode(WarrantyResponse.self, from: cached)
            if let response { return response.data?.warranty ?? [:] }
        }

        let encodedMake = make.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? make
        let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        let url = try buildURL(path: "/vehicle-warranty/\(year)/\(encodedMake)/\(encodedModel)")
        let data = try await performRequest(url: url)
        let response = try JSONDecoder().decode(WarrantyResponse.self, from: data)

        await supabase.storeCachedVehicleData(cacheKey: cacheKey, endpoint: endpoint, json: data)

        return response.data?.warranty ?? [:]
    }

    private func buildURL(path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else {
            throw VehicleAPIError.invalidURL
        }
        return url
    }

    private func performRequest(url: URL) async throws -> Data {
        guard let apiKey else { throw VehicleAPIError.noData }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-authkey")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VehicleAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw VehicleAPIError.httpError(httpResponse.statusCode)
        }

        return data
    }
}
