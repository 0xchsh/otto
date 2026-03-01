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

    @State private var dragOffset: CGFloat = 0
    private let sidebarFraction: CGFloat = 0.82

    private let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.85)

    var body: some View {
        Group {
            if vehicles.isEmpty {
                OnboardingView()
            } else {
                GeometryReader { geo in
                    let sidebarWidth = geo.size.width * sidebarFraction

                    ZStack(alignment: .leading) {
                        // Sidebar — sits behind, revealed when main content pushes right
                        ChatHistoryView()
                            .frame(width: sidebarWidth)

                        // Main content — pushes right when sidebar opens
                        mainContent(geo: geo, sidebarWidth: sidebarWidth)
                    }
                    .gesture(sidebarDragGesture(sidebarWidth: sidebarWidth))
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .onAppear {
            if appState.activeVehicle == nil {
                appState.activeVehicle = vehicles.first(where: { $0.isActive }) ?? vehicles.first
            }
        }
        .onChange(of: vehicles.count) { oldCount, newCount in
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

    @ViewBuilder
    private func mainContent(geo: GeometryProxy, sidebarWidth: CGFloat) -> some View {
        NavigationStack {
            ChatView()
        }
        .frame(width: geo.size.width, height: geo.size.height)
        .offset(x: mainOffset(sidebarWidth: sidebarWidth))
        .scaleEffect(appState.showSidebar ? 0.93 : 1.0)
        .clipShape(RoundedRectangle(cornerRadius: appState.showSidebar ? 20 : 0))
        .shadow(color: .black.opacity(appState.showSidebar ? 0.12 : 0), radius: 12, x: -4)
        .overlay {
            if appState.showSidebar {
                Color.black.opacity(0.05)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(springAnimation) {
                            appState.showSidebar = false
                        }
                    }
            }
        }
        .animation(springAnimation, value: appState.showSidebar)
    }

    private func mainOffset(sidebarWidth: CGFloat) -> CGFloat {
        if appState.showSidebar {
            return sidebarWidth + min(dragOffset, 0)
        } else {
            return max(dragOffset, 0)
        }
    }

    private func sidebarDragGesture(sidebarWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if appState.showSidebar {
                    // Drag left to close
                    if value.translation.width < 0 {
                        dragOffset = value.translation.width
                    }
                } else {
                    // Drag right from left edge to open
                    if value.startLocation.x < 30 && value.translation.width > 0 {
                        dragOffset = value.translation.width
                    }
                }
            }
            .onEnded { value in
                if appState.showSidebar {
                    if value.translation.width < -80 || value.predictedEndTranslation.width < -120 {
                        withAnimation(springAnimation) { appState.showSidebar = false }
                    }
                } else {
                    if value.startLocation.x < 30 &&
                       (value.translation.width > 80 || value.predictedEndTranslation.width > 120) {
                        withAnimation(springAnimation) { appState.showSidebar = true }
                    }
                }
                withAnimation(springAnimation) { dragOffset = 0 }
            }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: [Vehicle.self, ChatSession.self, ChatMessage.self], inMemory: true)
}
