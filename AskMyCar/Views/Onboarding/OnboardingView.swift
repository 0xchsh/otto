import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @State private var viewModel = OnboardingViewModel()
    @State private var showIntro = true
    @State private var showMakePicker = false
    @State private var showModelPicker = false

    private var isFirstVehicle: Bool { vehicles.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if isFirstVehicle && showIntro {
                    introView
                        .transition(.move(edge: .leading))
                } else {
                    addVehicleView
                        .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showIntro)
        }
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "car.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.appAccent)

            VStack(spacing: 12) {
                Text("Welcome to AskMyCar")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Your AI-powered vehicle assistant")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                featureBullet(icon: "bubble.left.and.text.bubble.right", text: "Ask anything about your car")
                featureBullet(icon: "wrench.and.screwdriver", text: "Track maintenance schedules")
                featureBullet(icon: "exclamationmark.triangle", text: "Stay on top of recalls & warranties")
            }
            .padding(.horizontal)

            Spacer()

            Button {
                withAnimation { showIntro = false }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private func featureBullet(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.appAccent)
                .frame(width: 28)
            Text(text)
                .font(.body)
        }
    }

    // MARK: - Add Vehicle

    private var addVehicleView: some View {
        VStack(spacing: 0) {
            Picker("Input Mode", selection: $viewModel.inputMode) {
                ForEach(VehicleInputMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                VStack(spacing: 16) {
                    switch viewModel.inputMode {
                    case .vin:
                        vinContent
                    case .ymm:
                        ymmContent
                    }

                    nicknameField
                }
                .padding(.horizontal)
                .padding(.bottom)
            }

            addButton
                .padding()
        }
        .navigationTitle("Add Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isFirstVehicle {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
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

    // MARK: - VIN Content

    private var vinContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Vehicle Identification Number is a 17-character code found on your dashboard or door jamb.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .trailing, spacing: 8) {
                TextField("e.g. 1HGBH41JXMN109186", text: $viewModel.vinText)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color.appSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: viewModel.vinText) { _, newValue in
                        viewModel.vinText = viewModel.filterVINInput(newValue)
                    }

                HStack {
                    if let error = viewModel.vinError {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    Text("\(viewModel.vinText.count)/17")
                        .font(.caption)
                        .foregroundStyle(viewModel.vinText.count == 17 ? .green : .secondary)
                }
            }
        }
    }

    // MARK: - YMM Content

    private var ymmContent: some View {
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

            Button { showMakePicker = true } label: {
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

            Button { showModelPicker = true } label: {
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
        }
    }

    // MARK: - Nickname

    private var nicknameField: some View {
        TextField("Nickname (optional, e.g. Hugo)", text: $viewModel.nickname)
            .textInputAutocapitalization(.words)
            .padding()
            .background(Color.appSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            Task {
                let success = await viewModel.addVehicle(in: modelContext, appState: appState)
                if success {
                    appState.showGarage = false
                    dismiss()
                }
            }
        } label: {
            HStack {
                if viewModel.isDecodingVIN && viewModel.inputMode == .vin {
                    ProgressView().tint(.white)
                }
                Image(systemName: "plus")
                Text("Add a vehicle")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.canAdd ? Color.appAccent : Color.gray)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!viewModel.canAdd)
    }

    private var yearRange: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(stride(from: currentYear + 1, through: 1980, by: -1))
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
        .modelContainer(for: [Vehicle.self, ChatSession.self, ChatMessage.self], inMemory: true)
}
