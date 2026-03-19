import Foundation

enum VehicleImageError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case httpError(Int)
    case noImageURL
    case noVariantsFound
    case noTrimsFound
    case vehicleNotAvailable

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Vehicle Imagery API key not configured"
        case .invalidResponse: return "Invalid response from Vehicle Imagery API"
        case .httpError(let code): return "Vehicle Imagery HTTP error: \(code)"
        case .noImageURL: return "No image URL in response"
        case .noVariantsFound: return "No variants found for this vehicle"
        case .noTrimsFound: return "No trims found for this vehicle"
        case .vehicleNotAvailable: return "Vehicle not available in imagery database"
        }
    }
}

// MARK: - Response Types

private struct BrandsResponse: Codable {
    let brands: [String]?
}

private struct ModelsResponse: Codable {
    let models: [String]?
}

private struct YearsResponse: Codable {
    let years: [Int]?
}

private struct VariantsResponse: Codable {
    let variants: [String]?
}

private struct TrimsResponse: Codable {
    let trims: [String]?
}

private struct ImageResponse: Codable {
    let image_url: String?
}

private struct ColorsResponse: Codable {
    let colors: [String]?
}

// MARK: - Service

actor VehicleImageService {
    static let shared = VehicleImageService()

    private let baseURL = "https://api.vehicleimagery.com/api"
    private let session: URLSession
    private let signedURLLifetime: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    // In-memory caches (stable across app lifetime, no persistence needed)
    private var brandsCache: [String]?
    private var modelsCache: [String: [String]] = [:] // keyed by API brand name
    private var resolvedNames: [UUID: (brand: String, model: String, year: Int)] = [:] // keyed by vehicle ID
    private var urlCache: [String: URL] = [:] // keyed by "vehicleID:view:color"

    init(session: URLSession = .shared) {
        self.session = session
    }

    private var apiKey: String? {
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let key = dict["VEHICLE_IMAGERY_API_KEY"] as? String,
           !key.isEmpty {
            return key
        }
        return nil
    }

    // MARK: - Public

    /// Resolves API brand/model/year/variant/trim for a vehicle, caching results.
    private func resolveVehicle(_ vehicle: Vehicle, apiKey: String) async throws -> (brand: String, model: String, year: Int, variant: String, trim: String) {
        // Resolve API names (cached per vehicle ID)
        let apiBrand: String
        let apiModel: String
        let apiYear: Int

        if let resolved = resolvedNames[vehicle.id] {
            apiBrand = resolved.brand
            apiModel = resolved.model
            apiYear = resolved.year
        } else {
            apiBrand = try await resolveBrand(vehicle.make, apiKey: apiKey)
            apiModel = try await resolveModel(vehicle.model, brand: apiBrand, apiKey: apiKey)
            apiYear = try await resolveYear(vehicle.year, brand: apiBrand, model: apiModel, apiKey: apiKey)
            resolvedNames[vehicle.id] = (apiBrand, apiModel, apiYear)
        }

        // Resolve variant + trim
        let variant: String
        let trim: String

        if let rv = vehicle.resolvedVariant, let rt = vehicle.resolvedTrim {
            variant = rv
            trim = rt
        } else {
            let encodedBrand = encodePathComponent(apiBrand)
            let encodedModel = encodePathComponent(apiModel)

            let variantsURL = try buildURL(path: "/\(encodedBrand)/\(encodedModel)/\(apiYear)")
            let variantsData = try await performRequest(url: variantsURL, apiKey: apiKey)
            let variantsArray = try JSONDecoder().decode([VariantsResponse].self, from: variantsData)

            guard let variants = variantsArray.first?.variants, !variants.isEmpty else {
                throw VehicleImageError.noVariantsFound
            }

            let pickedVariant: String
            if let userTrim = vehicle.trim?.lowercased() {
                pickedVariant = variants.first { $0.lowercased().contains(userTrim) } ?? variants[0]
            } else {
                pickedVariant = variants[0]
            }

            let encodedVariant = encodePathComponent(pickedVariant)
            let trimsURL = try buildURL(path: "/\(encodedBrand)/\(encodedModel)/\(apiYear)/\(encodedVariant)")
            let trimsData = try await performRequest(url: trimsURL, apiKey: apiKey)
            let trimsArray = try JSONDecoder().decode([TrimsResponse].self, from: trimsData)

            guard let trims = trimsArray.first?.trims, !trims.isEmpty else {
                throw VehicleImageError.noTrimsFound
            }

            let pickedTrim: String
            if let userTrim = vehicle.trim?.lowercased() {
                pickedTrim = trims.first { $0.lowercased().contains(userTrim) } ?? trims[0]
            } else {
                pickedTrim = trims[0]
            }

            variant = pickedVariant
            trim = pickedTrim

            await MainActor.run {
                vehicle.resolvedVariant = variant
                vehicle.resolvedTrim = trim
            }
        }

        return (apiBrand, apiModel, apiYear, variant, trim)
    }

    /// Fetches a signed CDN image URL for the vehicle, resolving brand/model/variant/trim as needed.
    func fetchImageURL(for vehicle: Vehicle, color: String? = nil, view: String = "right") async throws -> URL {
        let colorParam = color ?? vehicle.exteriorColor ?? "default"
        let cacheKey = "\(vehicle.id):\(view):\(colorParam)"

        // Check in-memory URL cache first (survives SwiftUI view recreation)
        if let cached = urlCache[cacheKey] { return cached }

        // Check persisted per-view cache
        if let cached = vehicle.cachedImageURL(for: view),
           let url = URL(string: cached),
           color == nil || color == vehicle.exteriorColor {
            urlCache[cacheKey] = url
            return url
        }

        guard let apiKey else { throw VehicleImageError.noAPIKey }

        let resolved = try await resolveVehicle(vehicle, apiKey: apiKey)

        // Fetch the image
        let encodedBrand = encodePathComponent(resolved.brand)
        let encodedModel = encodePathComponent(resolved.model)
        let encodedVariant = encodePathComponent(resolved.variant)
        let encodedTrim = encodePathComponent(resolved.trim)
        let encodedColor = colorParam.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? colorParam
        let imagePath = "/\(encodedBrand)/\(encodedModel)/\(resolved.year)/\(encodedVariant)/\(encodedTrim)/\(view)?color=\(encodedColor)&transparency=true"
        let imageURL = try buildURL(path: imagePath)
        let imageData = try await performRequest(url: imageURL, apiKey: apiKey)
        let imageArray = try JSONDecoder().decode([ImageResponse].self, from: imageData)

        guard let urlString = imageArray.first?.image_url, let url = URL(string: urlString) else {
            throw VehicleImageError.noImageURL
        }

        // Cache the signed URL (in-memory + persisted)
        urlCache[cacheKey] = url
        let viewKey = view
        await MainActor.run {
            vehicle.setCachedImageURL(urlString, for: viewKey)
            vehicle.imageURLExpiry = Date().addingTimeInterval(self.signedURLLifetime)
        }

        return url
    }

    /// Fetches available OEM colors for the vehicle.
    func fetchAvailableColors(for vehicle: Vehicle) async throws -> [String] {
        guard let apiKey else { throw VehicleImageError.noAPIKey }

        let resolved = try await resolveVehicle(vehicle, apiKey: apiKey)
        let encodedBrand = encodePathComponent(resolved.brand)
        let encodedModel = encodePathComponent(resolved.model)
        let encodedVariant = encodePathComponent(resolved.variant)
        let encodedTrim = encodePathComponent(resolved.trim)

        let url = try buildURL(path: "/\(encodedBrand)/\(encodedModel)/\(resolved.year)/\(encodedVariant)/\(encodedTrim)/colors")
        let data = try await performRequest(url: url, apiKey: apiKey)
        let response = try JSONDecoder().decode([ColorsResponse].self, from: data)
        return response.first?.colors ?? []
    }

    // MARK: - Name Resolution

    /// Matches app brand name (e.g. "Bmw") to the API's brand name (e.g. "BMW").
    private func resolveBrand(_ appBrand: String, apiKey: String) async throws -> String {
        if brandsCache == nil {
            let url = try buildURL(path: "/brands")
            let data = try await performRequest(url: url, apiKey: apiKey)
            let response = try JSONDecoder().decode(BrandsResponse.self, from: data)
            brandsCache = response.brands ?? []
        }

        guard let brands = brandsCache else { throw VehicleImageError.vehicleNotAvailable }

        // Exact match first
        if let exact = brands.first(where: { $0 == appBrand }) { return exact }

        // Case-insensitive match
        let lowered = appBrand.lowercased()
        if let match = brands.first(where: { $0.lowercased() == lowered }) { return match }

        // Contains match (handles "Mercedes-Benz" vs "Mercedes" etc.)
        if let match = brands.first(where: { $0.lowercased().contains(lowered) || lowered.contains($0.lowercased()) }) {
            return match
        }

        throw VehicleImageError.vehicleNotAvailable
    }

    /// Matches app model name (e.g. "4 Series") to the API's model name (e.g. "4").
    private func resolveModel(_ appModel: String, brand: String, apiKey: String) async throws -> String {
        if modelsCache[brand] == nil {
            let encodedBrand = encodePathComponent(brand)
            let url = try buildURL(path: "/\(encodedBrand)")
            let data = try await performRequest(url: url, apiKey: apiKey)
            let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
            modelsCache[brand] = response.models ?? []
        }

        guard let models = modelsCache[brand] else { throw VehicleImageError.vehicleNotAvailable }

        // Exact match
        if let exact = models.first(where: { $0 == appModel }) { return exact }

        // Case-insensitive exact match
        let lowered = appModel.lowercased()
        if let match = models.first(where: { $0.lowercased() == lowered }) { return match }

        // The app uses "4 Series" but API uses "4" — check if appModel starts with the API model name
        if let match = models.first(where: { lowered.hasPrefix($0.lowercased()) }) { return match }

        // Check if API model starts with the app model
        if let match = models.first(where: { $0.lowercased().hasPrefix(lowered) }) { return match }

        // Contains match
        if let match = models.first(where: { $0.lowercased().contains(lowered) || lowered.contains($0.lowercased()) }) {
            return match
        }

        throw VehicleImageError.vehicleNotAvailable
    }

    /// Finds the nearest available year for a vehicle in the API.
    private func resolveYear(_ appYear: Int, brand: String, model: String, apiKey: String) async throws -> Int {
        let encodedBrand = encodePathComponent(brand)
        let encodedModel = encodePathComponent(model)
        let url = try buildURL(path: "/\(encodedBrand)/\(encodedModel)")
        let data = try await performRequest(url: url, apiKey: apiKey)
        let response = try JSONDecoder().decode([YearsResponse].self, from: data)

        guard let years = response.first?.years, !years.isEmpty else {
            throw VehicleImageError.vehicleNotAvailable
        }

        // Exact match
        if years.contains(appYear) { return appYear }

        // Nearest year (prefer closest, tie-break to newer)
        let sorted = years.sorted()
        return sorted.min(by: { abs($0 - appYear) < abs($1 - appYear) }) ?? sorted.last!
    }

    // MARK: - Helpers

    private func encodePathComponent(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private func buildURL(path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else {
            throw VehicleImageError.invalidResponse
        }
        return url
    }

    private func performRequest(url: URL, apiKey: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VehicleImageError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw VehicleImageError.vehicleNotAvailable
            }
            throw VehicleImageError.httpError(httpResponse.statusCode)
        }

        return data
    }
}
