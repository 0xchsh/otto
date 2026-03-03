import Foundation
import SwiftData

enum OnboardingStep {
    case intro
    case welcome
    case vinEntry
    case makeModelEntry
    case confirmation
}

@Observable
@MainActor
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .intro
    var vinText = ""
    var make = "" {
        didSet {
            if oldValue != make { model = "" }
        }
    }
    var model = ""
    var year = Calendar.current.component(.year, from: Date())
    var trim = ""
    var nickname = ""
    var isValidatingVIN = false
    var vinValidationError: String?
    var decodedVINInfo: VINInfo?

    var canDecodeVIN: Bool {
        vinText.count == 17
    }

    var canAddVehicle: Bool {
        !make.trimmingCharacters(in: .whitespaces).isEmpty &&
        !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func validateAndDecodeVIN() {
        isValidatingVIN = true
        vinValidationError = nil

        let result = VINDecoderService.validate(vinText)
        switch result {
        case .valid:
            if let info = VINDecoderService.decode(vinText) {
                decodedVINInfo = info
                currentStep = .confirmation
            }
        case .invalidLength:
            vinValidationError = "VIN must be exactly 17 characters"
        case .invalidCharacters:
            vinValidationError = "VIN contains invalid characters (I, O, Q not allowed)"
        case .invalidCheckDigit:
            vinValidationError = "VIN check digit is invalid"
        }

        isValidatingVIN = false
    }

    func createVehicle(in context: ModelContext) -> Vehicle {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespaces)
        let vehicle = Vehicle(
            make: make.trimmingCharacters(in: .whitespaces),
            model: model.trimmingCharacters(in: .whitespaces),
            year: year,
            vin: vinText.isEmpty ? nil : vinText.uppercased(),
            trim: trim.trimmingCharacters(in: .whitespaces).isEmpty ? nil : trim.trimmingCharacters(in: .whitespaces),
            nickname: trimmedNickname.isEmpty ? nil : trimmedNickname
        )
        context.insert(vehicle)
        return vehicle
    }

    func filterVINInput(_ input: String) -> String {
        let uppercased = input.uppercased()
        let filtered = uppercased.filter { char in
            char != "I" && char != "O" && char != "Q" && (char.isLetter || char.isNumber)
        }
        return String(filtered.prefix(17))
    }
}
