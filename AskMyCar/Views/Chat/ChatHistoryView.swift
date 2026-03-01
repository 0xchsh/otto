import SwiftUI
import SwiftData

struct ChatHistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var sessions: [ChatSession]
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AskMyCar")
                    .font(.title2.bold())

                Spacer()

                Button {
                    createNewSession()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                }

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Session list
            if sessions.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No Conversations")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Tap + to start a new chat")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                List {
                    ForEach(sessions, id: \.id) { session in
                        Button {
                            selectSession(session)
                        } label: {
                            ChatHistoryRow(session: session)
                        }
                        .tint(.primary)
                        .listRowBackground(
                            session.id == appState.activeSession?.id
                            ? Color.appAccent.opacity(0.12)
                            : Color.clear
                        )
                    }
                    .onDelete(perform: deleteSessions)
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private func selectSession(_ session: ChatSession) {
        appState.activeSession = session
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            appState.showSidebar = false
        }
    }

    private func createNewSession() {
        guard let vehicle = appState.activeVehicle else { return }
        let session = ChatSession(title: "New Chat", vehicle: vehicle)
        modelContext.insert(session)
        appState.activeSession = session
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            appState.showSidebar = false
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            let wasActive = session.id == appState.activeSession?.id
            modelContext.delete(session)
            if wasActive {
                appState.activeSession = sessions.first(where: { $0.id != session.id })
            }
        }
    }
}

#Preview {
    ChatHistoryView()
        .environment(AppState())
        .modelContainer(for: [Vehicle.self, ChatSession.self, ChatMessage.self], inMemory: true)
}
