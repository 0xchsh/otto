import Foundation
import SwiftData
import UIKit

@Observable
@MainActor
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var selectedImages: [UIImage] = []
    var isLoading = false
    var isStreaming = false
    var errorMessage: String?
    var isLoadingVehicleData = false

    private var currentSession: ChatSession?
    private var streamTask: Task<Void, Never>?
    private let aiService = AIService()
    private let vehicleAPIService = VehicleAPIService()
    private var profileDocument: String?

    func loadSession(_ session: ChatSession) {
        currentSession = session
        messages = session.sortedMessages

        guard let vehicle = session.vehicle else { return }

        // Use cached profile document if available
        if let cached = vehicle.cachedProfileDocument {
            profileDocument = cached
        } else {
            // Fetch from API, build profile, and cache it
            isLoadingVehicleData = true
            let vin = vehicle.vin
            let year = vehicle.year
            let make = vehicle.make
            let model = vehicle.model
            let trim = vehicle.trim
            let nickname = vehicle.nickname

            Task {
                let apiData = await vehicleAPIService.fetchVehicleContext(
                    vin: vin, year: year, make: make, model: model
                )

                let doc = VehicleContext.buildProfileDocument(
                    nickname: nickname,
                    year: year,
                    make: make,
                    model: model,
                    trim: trim,
                    vin: vin,
                    apiData: apiData
                )

                profileDocument = doc
                // Persist on the vehicle so we never re-fetch
                vehicle.cachedProfileDocument = doc
                cacheRawAPIData(apiData, on: vehicle)
                isLoadingVehicleData = false
            }
        }
    }

    func removeImage(at index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages.remove(at: index)
    }

    func sendMessage(in context: ModelContext) {
        guard let session = currentSession, let vehicle = session.vehicle else { return }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !selectedImages.isEmpty else { return }

        // Compress selected images to JPEG
        let imageDataArray: [Data]? = selectedImages.isEmpty ? nil : selectedImages.compactMap {
            $0.jpegData(compressionQuality: 0.7)
        }
        inputText = ""
        selectedImages = []
        errorMessage = nil

        let userMessage = ChatMessage(role: .user, content: text, imageData: imageDataArray)
        userMessage.session = currentSession
        context.insert(userMessage)
        messages.append(userMessage)
        currentSession?.updatedAt = Date()

        // Auto-title session after first user message
        if messages.filter({ $0.role == .user }).count == 1 {
            currentSession?.title = text.count > 50 ? String(text.prefix(50)) + "..." : text
        }

        let assistantMessage = ChatMessage(role: .assistant, content: "")
        assistantMessage.session = currentSession
        context.insert(assistantMessage)
        messages.append(assistantMessage)

        isLoading = true
        isStreaming = true

        let systemPrompt = AIService.buildSystemPrompt(
            for: vehicle,
            vehicleProfile: profileDocument
        )

        var aiMessages: [AIMessage] = [
            AIMessage(role: "system", content: systemPrompt)
        ]

        for msg in messages where msg.role != .system {
            if msg.id == assistantMessage.id { continue }
            aiMessages.append(AIMessage(role: msg.role.rawValue, content: msg.content, images: msg.imageData))
        }

        streamTask = Task {
            do {
                var fullResponse = ""
                let stream = await aiService.streamChat(messages: aiMessages)
                isLoading = false

                for try await chunk in stream {
                    fullResponse += chunk
                    assistantMessage.content = fullResponse
                    if let index = messages.lastIndex(where: { $0.id == assistantMessage.id }) {
                        messages[index] = assistantMessage
                    }
                }

                isStreaming = false
            } catch {
                isLoading = false
                isStreaming = false
                if assistantMessage.content.isEmpty {
                    if let index = messages.lastIndex(where: { $0.id == assistantMessage.id }) {
                        messages.remove(at: index)
                    }
                    context.delete(assistantMessage)
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isLoading = false
        isStreaming = false
    }

    func suggestedPrompts(for vehicle: Vehicle) -> [String] {
        [
            "What's the recommended maintenance schedule?",
            "What are common issues with my \(vehicle.displayName)?",
            "What type of oil should I use?",
            "What's the tire pressure recommendation?",
            "Tell me about the safety features",
            "What's the towing capacity?"
        ]
    }

    // MARK: - Caching

    private func cacheRawAPIData(_ apiData: VehicleContext, on vehicle: Vehicle) {
        vehicle.cachedOwnerManualURL = apiData.ownerManualURL

        if let maintenance = apiData.maintenance,
           let data = try? JSONEncoder().encode(maintenance) {
            vehicle.cachedMaintenanceJSON = String(data: data, encoding: .utf8)
        }
        if let recalls = apiData.recalls,
           let data = try? JSONEncoder().encode(recalls) {
            vehicle.cachedRecallsJSON = String(data: data, encoding: .utf8)
        }
        if let warranty = apiData.warranty,
           let data = try? JSONEncoder().encode(warranty) {
            vehicle.cachedWarrantyJSON = String(data: data, encoding: .utf8)
        }

        vehicle.vehicleDataLastFetched = Date()
    }
}
