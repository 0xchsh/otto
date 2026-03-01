import SwiftUI
import SwiftData

@Observable
final class AppState {
    var activeVehicle: Vehicle?
    var showGarage = false
    var showSidebar = false
    var activeSession: ChatSession?
    var errorMessage: String?
}
