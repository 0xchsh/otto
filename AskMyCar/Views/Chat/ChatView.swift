import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool

    private var session: ChatSession? { appState.activeSession }
    private var vehicle: Vehicle? { session?.vehicle }

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            if session != nil {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if viewModel.messages.isEmpty {
                                emptyStateView
                            }

                            ForEach(viewModel.messages, id: \.id) { message in
                                if message.role != .system {
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                            }

                            if viewModel.isLoading {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding(.vertical)
                    }
                    .dismissKeyboardOnTap()
                    .onChange(of: viewModel.messages.count) {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.messages.last?.content) {
                        scrollToBottom(proxy: proxy)
                    }
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.appAccent)
                    Text("Select or start a conversation")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error) {
                    withAnimation { viewModel.errorMessage = nil }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if session != nil {
                inputBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        state.showSidebar.toggle()
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.body)
                }
            }

            ToolbarItem(placement: .principal) {
                if let vehicle {
                    VStack(spacing: 2) {
                        Text(vehicle.topBarName)
                            .font(.headline)
                        Text(vehicle.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    state.showGarage = true
                } label: {
                    Image(systemName: "car.fill")
                        .font(.body)
                }
            }
        }
        .sheet(isPresented: $state.showGarage) {
            GarageView()
        }
        .onAppear {
            if let session {
                viewModel.loadSession(session)
            }
        }
        .onChange(of: appState.activeSession) { _, newSession in
            if let newSession {
                viewModel.loadSession(newSession)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "car.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.appAccent)

            if let vehicle {
                Text("Ask anything about your \(vehicle.displayName)")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                SuggestedPrompts(prompts: viewModel.suggestedPrompts(for: vehicle)) { prompt in
                    viewModel.inputText = prompt
                    sendMessage()
                }
            }
        }
        .padding()
    }

    private var presetQuestions: [String] {
        [
            "What's my maintenance schedule?",
            "What type of oil should I use?",
            "What's the recommended tire pressure?"
        ]
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            if viewModel.messages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presetQuestions, id: \.self) { question in
                            Button {
                                viewModel.inputText = question
                                sendMessage()
                            } label: {
                                Text(question)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appPrimaryText)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.appSecondaryBackground)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }

            HStack(spacing: 12) {
                TextField(
                    vehicle.map { "Ask a question about your \($0.make)" } ?? "Ask about your car...",
                    text: $viewModel.inputText,
                    axis: .vertical
                )
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.appSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                if viewModel.isStreaming {
                    Button {
                        viewModel.stopStreaming()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Color.red)
                    }
                } else {
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(
                                viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.gray : Color.appAccent
                            )
                    }
                    .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func sendMessage() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        viewModel.sendMessage(in: modelContext)
    }

    private func createNewSession() {
        guard let vehicle = appState.activeVehicle else { return }
        let session = ChatSession(title: "New Chat", vehicle: vehicle)
        modelContext.insert(session)
        appState.activeSession = session
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if viewModel.isLoading {
            withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
        } else if let lastMessage = viewModel.messages.last {
            withAnimation { proxy.scrollTo(lastMessage.id, anchor: .bottom) }
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
    .environment(AppState())
    .modelContainer(for: [Vehicle.self, ChatSession.self, ChatMessage.self], inMemory: true)
}
