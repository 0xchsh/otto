import Foundation
import SwiftData

enum VehicleInputMode: String, CaseIterable {
    case vin = "By VIN"
    case ymm = "By YMM"
}

@Observable
@MainActor
final class OnboardingViewModel {
    var inputMode: VehicleInputMode = .vin

    // VIN fields
    var vinText = ""
    var isDecodingVIN = false
    var vinError: String?

    // YMM fields
    var make = "" {
        didSet { if oldValue != make { model = "" } }
    }
    var model = ""
    var year = Calendar.current.component(.year, from: Date())
    var trim = ""
    var nickname = ""

    var canAddByVIN: Bool { vinText.count == 17 && !isDecodingVIN }

    var canAddByYMM: Bool {
        !make.trimmingCharacters(in: .whitespaces).isEmpty &&
        !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canAdd: Bool {
        switch inputMode {
        case .vin: return canAddByVIN
        case .ymm: return canAddByYMM
        }
    }

    func addVehicle(in context: ModelContext, appState: AppState) async -> Bool {
        switch inputMode {
        case .vin:
            return await addVehicleByVIN(in: context, appState: appState)
        case .ymm:
            return addVehicleByYMM(in: context, appState: appState)
        }
    }

    private func addVehicleByVIN(in context: ModelContext, appState: AppState) async -> Bool {
        isDecodingVIN = true
        vinError = nil

        // Validate VIN format locally
        let result = VINDecoderService.validate(vinText)
        switch result {
        case .valid:
            break
        case .invalidLength:
            vinError = "VIN must be exactly 17 characters"
            isDecodingVIN = false
            return false
        case .invalidCharacters:
            vinError = "VIN contains invalid characters (I, O, Q not allowed)"
            isDecodingVIN = false
            return false
        case .invalidCheckDigit:
            vinError = "VIN check digit is invalid"
            isDecodingVIN = false
            return false
        }

        // Decode VIN via NHTSA to get make/model/year
        do {
            let decoded = try await NHTSAService.decodeVIN(vinText)
            let trimmedNickname = nickname.trimmingCharacters(in: .whitespaces)
            let vehicle = Vehicle(
                make: decoded.make,
                model: decoded.model,
                year: decoded.year,
                vin: vinText.uppercased(),
                trim: decoded.trim,
                nickname: trimmedNickname.isEmpty ? nil : trimmedNickname
            )
            finalizeVehicle(vehicle, in: context, appState: appState)
            isDecodingVIN = false
            return true
        } catch {
            vinError = "Could not decode VIN. Please try again or enter details manually."
            isDecodingVIN = false
            return false
        }
    }

    private func addVehicleByYMM(in context: ModelContext, appState: AppState) -> Bool {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespaces)
        let vehicle = Vehicle(
            make: make.trimmingCharacters(in: .whitespaces),
            model: model.trimmingCharacters(in: .whitespaces),
            year: year,
            trim: trim.trimmingCharacters(in: .whitespaces).isEmpty ? nil : trim.trimmingCharacters(in: .whitespaces),
            nickname: trimmedNickname.isEmpty ? nil : trimmedNickname
        )
        finalizeVehicle(vehicle, in: context, appState: appState)
        return true
    }

    private func finalizeVehicle(_ vehicle: Vehicle, in context: ModelContext, appState: AppState) {
        context.insert(vehicle)
        let session = ChatSession(title: "New Chat", vehicle: vehicle)
        context.insert(session)
        appState.activeVehicle = vehicle
        appState.activeSession = session
    }

    func filterVINInput(_ input: String) -> String {
        let uppercased = input.uppercased()
        let filtered = uppercased.filter { char in
            char != "I" && char != "O" && char != "Q" && (char.isLetter || char.isNumber)
        }
        return String(filtered.prefix(17))
    }
}
