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

struct AIMessage: Codable {
    let role: String
    let content: String
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
                    guard let apiKey = KeychainService.load(key: AIService.apiKeyKeychainKey), !apiKey.isEmpty else {
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
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
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

    static func buildSystemPrompt(for vehicle: Vehicle, context: String? = nil) -> String {
        var prompt = """
        You are a friendly, knowledgeable car expert helping the owner of a \(vehicle.fullDisplayName).
        Reply in a warm, conversational tone — like a trusted mechanic friend.
        Keep answers concise and easy to scan. Use short paragraphs and line breaks for readability.
        You may use **bold** for emphasis, but do NOT use markdown headers (#), horizontal rules (---), or bullet lists (- item). Just write naturally.
        If you're unsure about something specific to this exact vehicle, say so honestly rather than guessing.
        """

        if let vin = vehicle.vin {
            prompt += "\nThe vehicle's VIN is \(vin)."
        }

        if let context {
            prompt += "\n\nAdditional context:\n\(context)"
        }

        return prompt
    }
}
