import SwiftUI

struct MakeModelEntryView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showMakePicker = false
    @State private var showModelPicker = false

    private var yearRange: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(stride(from: currentYear + 1, through: 1980, by: -1))
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Vehicle Details")
                .font(.title2.bold())

            VStack(spacing: 16) {
                HStack {
                    Text("Year")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Year", selection: $viewModel.year) {
                        ForEach(yearRange, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding()
                .background(Color.appSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Make picker row
                Button {
                    showMakePicker = true
                } label: {
                    HStack {
                        Text(viewModel.make.isEmpty ? "Make (e.g. Toyota)" : viewModel.make)
                            .foregroundStyle(viewModel.make.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.appSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Model picker row
                Button {
                    showModelPicker = true
                } label: {
                    HStack {
                        Text(viewModel.model.isEmpty ? "Model (e.g. Camry)" : viewModel.model)
                            .foregroundStyle(viewModel.model.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.appSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(viewModel.make.isEmpty)
                .opacity(viewModel.make.isEmpty ? 0.5 : 1)

                TextField("Trim (optional, e.g. XSE)", text: $viewModel.trim)
                    .textInputAutocapitalization(.characters)
                    .padding()
                    .background(Color.appSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                TextField("Name your car (optional, e.g. Hugo)", text: $viewModel.nickname)
                    .textInputAutocapitalization(.words)
                    .padding()
                    .background(Color.appSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                viewModel.currentStep = .confirmation
            } label: {
                Text("Add Vehicle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canAddVehicle ? Color.appAccent : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!viewModel.canAddVehicle)
        }
        .padding()
        .sheet(isPresented: $showMakePicker) {
            SearchablePickerSheet(
                title: "Select Make",
                items: VehicleData.makes,
                selection: $viewModel.make
            )
        }
        .sheet(isPresented: $showModelPicker) {
            SearchablePickerSheet(
                title: "Select Model",
                items: VehicleData.models(for: viewModel.make),
                selection: $viewModel.model
            )
        }
    }
}

private struct SearchablePickerSheet: View {
    let title: String
    let items: [String]
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [String] {
        if searchText.isEmpty { return items }
        return items.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered, id: \.self) { item in
                    Button {
                        selection = item
                        dismiss()
                    } label: {
                        HStack {
                            Text(item)
                                .foregroundStyle(.primary)
                            Spacer()
                            if item == selection {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    MakeModelEntryView(viewModel: OnboardingViewModel())
}
