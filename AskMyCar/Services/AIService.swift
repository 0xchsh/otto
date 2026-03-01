import Foundation

enum AIServiceError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case httpError(Int, String?)
    case streamError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No API key configured. Add your API key in Settings."
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid response from AI service"
        case .httpError(let code, let message): return "HTTP \(code): \(message ?? "Unknown error")"
        case .streamError(let message): return "Stream error: \(message)"
        }
    }
}

struct AIMessage {
    let role: String
    let content: String
    var images: [Data]?

    init(role: String, content: String, images: [Data]? = nil) {
        self.role = role
        self.content = content
        self.images = images
    }

    func toDict() -> [String: Any] {
        if let images, !images.isEmpty {
            var contentArray: [[String: Any]] = [
                ["type": "text", "text": content]
            ]
            for imageData in images {
                let base64 = imageData.base64EncodedString()
                contentArray.append([
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
                ])
            }
            return ["role": role, "content": contentArray]
        }
        return ["role": role, "content": content]
    }
}

actor AIService {
    static let apiKeyKeychainKey = "ai_api_key"
    static let baseURLKey = "ai_base_url"
    static let modelKey = "ai_model"

    static let defaultBaseURL = "https://openrouter.ai/api/v1"
    static let defaultModel = "anthropic/claude-sonnet-4-6"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    var baseURL: String {
        UserDefaults.standard.string(forKey: AIService.baseURLKey) ?? AIService.defaultBaseURL
    }

    var model: String {
        UserDefaults.standard.string(forKey: AIService.modelKey) ?? AIService.defaultModel
    }

    func streamChat(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let apiKey = AIService.resolveAPIKey(), !apiKey.isEmpty else {
                        throw AIServiceError.noAPIKey
                    }

                    guard let url = URL(string: "\(baseURL)/chat/completions") else {
                        throw AIServiceError.invalidURL
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

                    let body: [String: Any] = [
                        "model": model,
                        "messages": messages.map { $0.toDict() },
                        "stream": true
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIServiceError.invalidResponse
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        throw AIServiceError.httpError(httpResponse.statusCode, nil)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))

                        if payload == "[DONE]" { break }

                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String else {
                            continue
                        }

                        continuation.yield(content)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    static func resolveAPIKey() -> String? {
        // 1. Check Keychain (set via Settings screen)
        if let key = KeychainService.load(key: AIService.apiKeyKeychainKey), !key.isEmpty {
            return key
        }
        // 2. Fall back to Secrets.plist
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let key = dict["OPENROUTER_API_KEY"] as? String,
           key != "YOUR_KEY_HERE" && !key.isEmpty {
            return key
        }
        return nil
    }

    static func buildSystemPrompt(for vehicle: Vehicle, vehicleProfile: String? = nil) -> String {
        var prompt = """
        You are a helpful car expert talking to the owner of a \(vehicle.fullDisplayName).
        Talk like a knowledgeable friend — casual, clear, and straight to the point.

        Rules for every reply:
        • Give the specific answer first, then explain briefly if needed.
        • Use **bold** for key facts (e.g. fuel type, part numbers, specs).
        • Keep it short — a few sentences is usually enough. No filler.
        • Do NOT use markdown headers (#), horizontal rules (---), or bullet lists (- item). Write in plain, natural sentences and short paragraphs.
        • Never lecture or over-explain. The owner just wants a quick, trustworthy answer.
        • If you're not sure about something for this exact vehicle, say so — don't guess.
        • Do NOT point out model year mismatches or decode the VIN unless the user asks. Just answer their question for the vehicle on file.
        • When referencing the owner's manual, mention it's available as a PDF and give the link if you have it.
        • Use the maintenance schedule, recalls, and warranty data below to give accurate, vehicle-specific answers.
        """

        if let vehicleProfile {
            prompt += "\n\n\(vehicleProfile)"
        }

        return prompt
    }
}
