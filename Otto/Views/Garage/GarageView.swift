import SwiftUI
import SwiftData

struct GarageView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Vehicle.createdAt, order: .reverse) private var vehicles: [Vehicle]
    @State private var viewModel = GarageViewModel()
    @State private var vehicleToRename: Vehicle?
    @State private var vehicleToDelete: Vehicle?
    @State private var vehicleToRecolor: Vehicle?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(vehicles, id: \.id) { vehicle in
                    VehicleCard(
                        vehicle: vehicle,
                        onChat: { startNewChat(with: vehicle) },
                        onRename: {
                            renameText = vehicle.nickname ?? ""
                            vehicleToRename = vehicle
                        },
                        onChangeColor: {
                            vehicleToRecolor = vehicle
                        },
                        onDelete: {
                            vehicleToDelete = vehicle
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { switchToVehicle(vehicle) }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
                .onDelete(perform: deleteVehicles)
            }
            .listStyle(.plain)
            .navigationTitle("Your Garage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showAddVehicle = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddVehicle) {
                OnboardingView()
            }
            .overlay {
                if vehicles.isEmpty {
                    ContentUnavailableView(
                        "No Vehicles",
                        systemImage: "car",
                        description: Text("Add your first vehicle to get started.")
                    )
                }
            }
            .alert("Rename Vehicle", isPresented: Binding(
                get: { vehicleToRename != nil },
                set: { if !$0 { vehicleToRename = nil } }
            )) {
                TextField("Nickname", text: $renameText)
                Button("Save") {
                    vehicleToRename?.nickname = renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    vehicleToRename = nil
                }
                Button("Cancel", role: .cancel) {
                    vehicleToRename = nil
                }
            }
            .alert(
                "Delete \(vehicleToDelete?.topBarName ?? "Vehicle")?",
                isPresented: Binding(
                    get: { vehicleToDelete != nil },
                    set: { if !$0 { vehicleToDelete = nil } }
                )
            ) {
                Button("Delete Vehicle", role: .destructive) {
                    Haptics.notification(.warning)
                    if let vehicle = vehicleToDelete {
                        viewModel.deleteVehicle(vehicle, in: modelContext, appState: appState)
                    }
                    vehicleToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    vehicleToDelete = nil
                }
            } message: {
                Text("Are you sure? All of your chats tied to this vehicle will be deleted.")
            }
            .sheet(item: $vehicleToRecolor) { vehicle in
                ColorPickerSheet(vehicle: vehicle)
            }
        }
    }

    private func switchToVehicle(_ vehicle: Vehicle) {
        Haptics.impact()

        // If tapping the already-active vehicle, just dismiss
        if vehicle.id == appState.activeVehicle?.id {
            dismiss()
            return
        }

        viewModel.setActiveVehicle(vehicle, allVehicles: vehicles, appState: appState)

        // Create a new chat session for the selected vehicle
        let session = ChatSession(title: "New Chat", vehicle: vehicle)
        modelContext.insert(session)

        // Load the new session
        appState.activeSession = session
        dismiss()
    }

    private func startNewChat(with vehicle: Vehicle) {
        Haptics.impact()

        viewModel.setActiveVehicle(vehicle, allVehicles: vehicles, appState: appState)

        let session = ChatSession(title: "New Chat", vehicle: vehicle)
        modelContext.insert(session)
        appState.activeSession = session
        dismiss()
    }

    private func deleteVehicles(at offsets: IndexSet) {
        if let index = offsets.first {
            vehicleToDelete = vehicles[index]
        }
    }

}

#Preview {
    GarageView()
        .environment(AppState())
        .modelContainer(for: [Vehicle.self, ChatSession.self, ChatMessage.self], inMemory: true)
}
