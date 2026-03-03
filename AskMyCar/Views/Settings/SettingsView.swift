import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var apiKey = ""
    @State private var baseURL = ""
    @State private var modelName = ""
    @State private var vehicleAPIKey = ""
    @State private var showDeleteConfirmation = false
    @State private var showClearHistoryConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("AI Configuration") {
                    SecureField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Base URL", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    TextField("Model", text: $modelName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Vehicle Data") {
                    SecureField("Vehicle Databases API Key", text: $vehicleAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Button("Save Settings") {
                        saveSettings()
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Clear Chat History", role: .destructive) {
                        showClearHistoryConfirmation = true
                    }
                    .confirmationDialog("Clear Chat History", isPresented: $showClearHistoryConfirmation, titleVisibility: .visible) {
                        Button("Clear All Chats", role: .destructive) {
                            clearChatHistory()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will delete all chat sessions and messages. Your vehicles will be kept.")
                    }

                    Button("Delete All Data", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .confirmationDialog("Delete All Data", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                        Button("Delete Everything", role: .destructive) {
                            deleteAllData()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all vehicles, chat sessions, and messages. This cannot be undone.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }

    private func loadSettings() {
        apiKey = KeychainService.load(key: AIService.apiKeyKeychainKey) ?? ""
        baseURL = UserDefaults.standard.string(forKey: AIService.baseURLKey) ?? AIService.defaultBaseURL
        modelName = UserDefaults.standard.string(forKey: AIService.modelKey) ?? AIService.defaultModel
        vehicleAPIKey = KeychainService.load(key: VehicleAPIService.apiKeyKeychainKey) ?? ""
    }

    private func saveSettings() {
        if !apiKey.isEmpty {
            KeychainService.save(key: AIService.apiKeyKeychainKey, value: apiKey)
        } else {
            KeychainService.delete(key: AIService.apiKeyKeychainKey)
        }

        if !vehicleAPIKey.isEmpty {
            KeychainService.save(key: VehicleAPIService.apiKeyKeychainKey, value: vehicleAPIKey)
        } else {
            KeychainService.delete(key: VehicleAPIService.apiKeyKeychainKey)
        }

        UserDefaults.standard.set(baseURL, forKey: AIService.baseURLKey)
        UserDefaults.standard.set(modelName, forKey: AIService.modelKey)
    }

    private func clearChatHistory() {
        do {
            try modelContext.delete(model: ChatMessage.self)
            try modelContext.delete(model: ChatSession.self)
        } catch {
            // Deletion failed silently
        }
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: ChatMessage.self)
            try modelContext.delete(model: ChatSession.self)
            try modelContext.delete(model: Vehicle.self)
        } catch {
            // Data deletion failed silently
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Vehicle.self, ChatSession.self, ChatMessage.self], inMemory: true)
}
