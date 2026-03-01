import SwiftUI
import SwiftData

@main
struct AskMyCarApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .fontDesign(.rounded)
        }
        .modelContainer(for: [Vehicle.self, ChatSession.self, ChatMessage.self])
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    var body: some View {
        @Bindable var state = appState

        Group {
            if vehicles.isEmpty {
                OnboardingView()
            } else {
                ZStack {
                    NavigationStack {
                        ChatView()
                    }

                    SidebarOverlay(isOpen: $state.showSidebar) {
                        ChatHistoryView()
                    }
                }
                .gesture(edgeSwipeGesture)
            }
        }
        .onAppear {
            if appState.activeVehicle == nil {
                appState.activeVehicle = vehicles.first(where: { $0.isActive }) ?? vehicles.first
            }
        }
        .onChange(of: vehicles.count) { oldCount, newCount in
            // First vehicle just added via onboarding
            if oldCount == 0 && newCount > 0 {
                let vehicle = vehicles.first(where: { $0.isActive }) ?? vehicles.first
                appState.activeVehicle = vehicle

                if let vehicle, appState.activeSession == nil {
                    let session = ChatSession(title: "New Chat", vehicle: vehicle)
                    modelContext.insert(session)
                    appState.activeSession = session
                }
            } else if appState.activeVehicle == nil {
                appState.activeVehicle = vehicles.first(where: { $0.isActive }) ?? vehicles.first
            }
        }
    }

    private var edgeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                // Open sidebar on right-swipe from left edge
                if value.startLocation.x < 30 &&
                   value.translation.width > 60 &&
                   !appState.showSidebar {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        appState.showSidebar = true
                    }
                }
            }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: [Vehicle.self, ChatSession.self, ChatMessage.self], inMemory: true)
}
