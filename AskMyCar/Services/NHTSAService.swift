import Foundation

enum NHTSAService {
    struct DecodedVehicle {
        let make: String
        let model: String
        let year: Int
        let trim: String?
    }

    static func decodeVIN(_ vin: String) async throws -> DecodedVehicle {
        let urlString = "https://vpic.nhtsa.dot.gov/api/vehicles/decodevinvalues/\(vin)?format=json"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let (data, _) = try await URLSession.shared.data(from: url)

        struct Response: Decodable {
            let Results: [VINResult]
        }

        struct VINResult: Decodable {
            let Make: String?
            let Model: String?
            let ModelYear: String?
            let Trim: String?
        }

        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let result = response.Results.first,
              let make = result.Make, !make.isEmpty,
              let model = result.Model, !model.isEmpty,
              let yearStr = result.ModelYear, let year = Int(yearStr) else {
            throw URLError(.cannotParseResponse)
        }

        return DecodedVehicle(
            make: make,
            model: model,
            year: year,
            trim: (result.Trim?.isEmpty ?? true) ? nil : result.Trim
        )
    }
}
