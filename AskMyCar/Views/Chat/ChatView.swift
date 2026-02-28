import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool

    let vehicle: Vehicle

    var body: some View {
        @Bindable var state = appState

        NavigationStack {
            VStack(spacing: 0) {
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

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        withAnimation { viewModel.errorMessage = nil }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                inputBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        state.showGarage = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.body)
                            .frame(width: 34, height: 34)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }

                ToolbarItem(placement: .principal) {
                    Button {
                        state.showGarage = true
                    } label: {
                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Text(vehicle.topBarName)
                                    .font(.headline)
                                    .foregroundStyle(Color.primary)
                                Image(systemName: "chevron.down")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Text(vehicle.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        state.showSettings = true
                    } label: {
                        Image(systemName: "car.fill")
                            .font(.body)
                            .frame(width: 34, height: 34)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadOrCreateSession(for: vehicle, in: modelContext)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "car.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.appAccent)

            Text("Ask anything about your \(vehicle.displayName)")
                .font(.headline)
                .multilineTextAlignment(.center)

            SuggestedPrompts(prompts: viewModel.suggestedPrompts(for: vehicle)) { prompt in
                viewModel.inputText = prompt
                sendMessage()
            }
        }
        .padding()
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask about your car...", text: $viewModel.inputText, axis: .vertical)
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
                        .font(.title2)
                        .foregroundStyle(Color.red)
                }
            } else {
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
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
        .background(.bar)
    }

    private func sendMessage() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        viewModel.sendMessage(for: vehicle, in: modelContext)
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
    ChatView(vehicle: Vehicle(make: "Toyota", model: "Camry", year: 2024))
        .environment(AppState())
        .modelContainer(for: [Vehicle.self, ChatSession.self, ChatMessage.self], inMemory: true)
}
