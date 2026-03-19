import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppState.self) private var appState
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
                        Haptics.notification(.success)
                        saveSettings()
                    }
                }

                Section("Subscription") {
                    if appState.subscriptionManager.isSubscribed {
                        HStack {
                            Text("Otto Premium")
                            Spacer()
                            Text("Active")
                                .foregroundStyle(.secondary)
                        }
                        Link("Manage Subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    } else {
                        Button("View Plans") {
                            dismiss()
                            appState.subscriptionManager.shouldShowPaywall = true
                        }
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

                    Button("Delete All Data", role: .destructive) {
                        showDeleteConfirmation = true
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
        .alert("Clear Chat History", isPresented: $showClearHistoryConfirmation) {
            Button("Clear All Chats", role: .destructive) {
                Haptics.notification(.warning)
                clearChatHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all chat sessions and messages. Your vehicles will be kept.")
        }
        .alert("Delete All Data", isPresented: $showDeleteConfirmation) {
            Button("Delete Everything", role: .destructive) {
                Haptics.notification(.error)
                deleteAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all vehicles, chat sessions, and messages. This cannot be undone.")
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
            let sessions = try modelContext.fetch(FetchDescriptor<ChatSession>())
            for session in sessions {
                modelContext.delete(session)
            }
            try modelContext.save()

            // Create a fresh session and dismiss settings
            if let vehicle = appState.activeVehicle {
                let newSession = ChatSession(title: "New Chat", vehicle: vehicle)
                modelContext.insert(newSession)
                appState.activeSession = newSession
            } else {
                appState.activeSession = nil
            }
            dismiss()
        } catch {
            // Silently handled — user can retry
        }
    }

    private func deleteAllData() {
        do {
            try modelContext.delete(model: ChatMessage.self)
            try modelContext.delete(model: ChatSession.self)
            try modelContext.delete(model: Vehicle.self)
            try modelContext.save()
            appState.activeSession = nil
            appState.activeVehicle = nil
            dismiss()
        } catch {
            // Silently handled — user can retry
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
        .modelContainer(for: [Vehicle.self, ChatSession.self, ChatMessage.self], inMemory: true)
}
