import SwiftUI
import SwiftData

struct GarageView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Vehicle.createdAt, order: .reverse) private var vehicles: [Vehicle]
    @State private var viewModel = GarageViewModel()
    @State private var vehicleToRename: Vehicle?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(vehicles, id: \.id) { vehicle in
                    VehicleCard(
                        vehicle: vehicle,
                        onRename: {
                            renameText = vehicle.nickname ?? ""
                            vehicleToRename = vehicle
                        },
                        onDelete: {
                            viewModel.deleteVehicle(vehicle, in: modelContext, appState: appState)
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { switchToVehicle(vehicle) }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
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
            .task {
                await fetchMissingPhotos()
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
        }
    }

    private func switchToVehicle(_ vehicle: Vehicle) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

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

    private func deleteVehicles(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteVehicle(vehicles[index], in: modelContext, appState: appState)
        }
    }

    private func fetchMissingPhotos() async {
        let service = AutoDevService.shared
        for vehicle in vehicles where vehicle.cachedPhotoURL == nil {
            if let url = await service.fetchPhotoURL(
                vin: vehicle.vin,
                year: vehicle.year,
                make: vehicle.make,
                model: vehicle.model
            ) {
                vehicle.cachedPhotoURL = url
            }
        }
    }
}

#Preview {
    GarageView()
        .environment(AppState())
        .modelContainer(for: [Vehicle.self, ChatSession.self, ChatMessage.self], inMemory: true)
}
