import SwiftUI
import SwiftData
import PhotosUI

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChatViewModel()
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @FocusState private var isInputFocused: Bool

    private var session: ChatSession? { appState.activeSession }
    private var vehicle: Vehicle? { session?.vehicle }

    var body: some View {
        @Bindable var state = appState

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
            Image(systemName: "car.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.appAccent)

            if let vehicle {
                Text("Ask anything about your \(vehicle.displayName)")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical) { height, _ in
            height
        }
    }

    private var presetQuestions: [String] {
        [
            "What's my maintenance schedule?",
            "What type of oil should I use?",
            "What's the recommended tire pressure?"
        ]
    }

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.selectedImages.isEmpty
    }

    private var imageThumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            withAnimation { viewModel.removeImage(at: index) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                                .background(Circle().fill(.black.opacity(0.5)))
                        }
                        .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }

    private var attachmentMenu: some View {
        Menu {
            PhotosPicker(
                selection: $photoPickerItems,
                maxSelectionCount: 5,
                matching: .images
            ) {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }

            Button {
                showCamera = true
            } label: {
                Label("Camera", systemImage: "camera")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.appSecondaryText)
                .frame(width: 32, height: 32)
        }
    }

    private var sendOrStopButton: some View {
        Group {
            if viewModel.isStreaming {
                Button {
                    viewModel.stopStreaming()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.red)
                }
            } else {
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(canSend ? Color.appAccent : Color.gray.opacity(0.4))
                }
                .disabled(!canSend)
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 12) {
            if !viewModel.selectedImages.isEmpty {
                imageThumbnails
            }

            TextField(
                vehicle.map { "Ask about your \($0.make)..." } ?? "Ask about your car...",
                text: $viewModel.inputText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(1...5)
            .focused($isInputFocused)

            HStack {
                attachmentMenu

                Spacer()

                sendOrStopButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color.appSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onChange(of: photoPickerItems) { _, newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        viewModel.selectedImages.append(uiImage)
                    }
                }
                photoPickerItems = []
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { image in
                viewModel.selectedImages.append(image)
            }
            .ignoresSafeArea()
        }
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
