import Foundation

actor AutoDevService {
    static let shared = AutoDevService()

    private let baseURL = "https://api.auto.dev"
    private let apiKey = "sk_ad_0_OU-Gbgm6TjZNKQHqG6hl08"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetch a vehicle photo URL. Uses VIN photos endpoint if available,
    /// otherwise falls back to listings search by make/model/year.
    func fetchPhotoURL(vin: String?, year: Int, make: String, model: String) async -> String? {
        // Try VIN-based photos first (better side profile selection)
        if let vin, !vin.isEmpty {
            if let url = try? await fetchPhotosByVIN(vin) {
                return url
            }
        }

        // Fallback: search listings by make/model/year
        return try? await fetchPhotoByListing(year: year, make: make, model: model)
    }

    // MARK: - Private

    /// Fetch photos by VIN and pick the side profile (index 1) or first available.
    private func fetchPhotosByVIN(_ vin: String) async throws -> String? {
        guard let url = URL(string: "\(baseURL)/photos/\(vin)") else {
            return nil
        }

        let data = try await performRequest(url: url)

        struct PhotosResponse: Codable {
            let data: PhotoData?
            struct PhotoData: Codable {
                let retail: [String]?
            }
        }

        let response = try JSONDecoder().decode(PhotosResponse.self, from: data)
        guard let photos = response.data?.retail, !photos.isEmpty else {
            return nil
        }

        // Side profile is typically the 2nd image (index 1)
        return photos.count > 1 ? photos[1] : photos[0]
    }

    /// Search listings by make/model/year. If the first result has a VIN,
    /// try to get a side profile from the photos API; otherwise use primaryImage.
    private func fetchPhotoByListing(year: Int, make: String, model: String) async throws -> String? {
        var components = URLComponents(string: "\(baseURL)/listings")!
        components.queryItems = [
            URLQueryItem(name: "vehicle.year", value: "\(year)"),
            URLQueryItem(name: "vehicle.make", value: make),
            URLQueryItem(name: "vehicle.model", value: model),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components.url else { return nil }

        let data = try await performRequest(url: url)

        struct ListingsResponse: Codable {
            let data: [Listing]?
            struct Listing: Codable {
                let vin: String?
                let retailListing: RetailListing?
                struct RetailListing: Codable {
                    let primaryImage: String?
                }
            }
        }

        let response = try JSONDecoder().decode(ListingsResponse.self, from: data)
        guard let listing = response.data?.first else { return nil }

        // Try side profile via photos API using the listing's VIN
        if let listingVIN = listing.vin,
           let sideProfile = try? await fetchPhotosByVIN(listingVIN) {
            return sideProfile
        }

        // Fallback to primaryImage
        return listing.retailListing?.primaryImage
    }

    private func performRequest(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VehicleAPIError.httpError(
                (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }

        return data
    }
}
