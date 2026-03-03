import SwiftUI
import SwiftData

struct ChatHistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var sessions: [ChatSession]
    @State private var showSettings = false

    private var groupedSessions: [(String, [ChatSession])] {
        let calendar = Calendar.current
        let now = Date()

        var today: [ChatSession] = []
        var yesterday: [ChatSession] = []
        var previous7Days: [ChatSession] = []
        var previous30Days: [ChatSession] = []
        var older: [ChatSession] = []

        let activeSessions = sessions.filter { !$0.messages.isEmpty }

        for session in activeSessions {
            if calendar.isDateInToday(session.updatedAt) {
                today.append(session)
            } else if calendar.isDateInYesterday(session.updatedAt) {
                yesterday.append(session)
            } else if let days = calendar.dateComponents([.day], from: session.updatedAt, to: now).day, days < 7 {
                previous7Days.append(session)
            } else if let days = calendar.dateComponents([.day], from: session.updatedAt, to: now).day, days < 30 {
                previous30Days.append(session)
            } else {
                older.append(session)
            }
        }

        var result: [(String, [ChatSession])] = []
        if !today.isEmpty { result.append(("Today", today)) }
        if !yesterday.isEmpty { result.append(("Yesterday", yesterday)) }
        if !previous7Days.isEmpty { result.append(("Previous 7 Days", previous7Days)) }
        if !previous30Days.isEmpty { result.append(("Previous 30 Days", previous30Days)) }
        if !older.isEmpty { result.append(("Older", older)) }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Large title
            HStack {
                Text("AskMyCar")
                    .font(.largeTitle.bold())
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)

            // Session list
            if groupedSessions.isEmpty {
                emptyState
            } else {
                sessionList
            }

            Spacer(minLength: 0)

            // Bottom bar
            bottomBar
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No Conversations")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap + to start a new chat")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private var sessionList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedSessions, id: \.0) { sectionTitle, sectionSessions in
                    Text(sectionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 6)

                    ForEach(sectionSessions, id: \.id) { session in
                        Button {
                            selectSession(session)
                        } label: {
                            ChatHistoryRow(
                                session: session,
                                isActive: session.id == appState.activeSession?.id
                            )
                        }
                        .padding(.horizontal, 8)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteSession(session)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }

    private var bottomBar: some View {
        HStack {
            Button {
                showSettings = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                        .font(.subheadline)
                }
                .foregroundStyle(Color.appSecondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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

    private func deleteSession(_ session: ChatSession) {
        let wasActive = session.id == appState.activeSession?.id
        modelContext.delete(session)
        if wasActive {
            appState.activeSession = sessions.first(where: { $0.id != session.id })
        }
    }
}

#Preview {
    ChatHistoryView()
        .environment(AppState())
        .modelContainer(for: [Vehicle.self, ChatSession.self, ChatMessage.self], inMemory: true)
}
