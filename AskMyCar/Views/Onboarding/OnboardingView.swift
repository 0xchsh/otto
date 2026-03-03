import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.currentStep {
                case .intro:
                    introView
                case .welcome:
                    welcomeView
                case .vinEntry:
                    VINEntryView(viewModel: viewModel)
                case .makeModelEntry:
                    MakeModelEntryView(viewModel: viewModel)
                case .confirmation:
                    confirmationView
                }
            }
            .animation(.easeInOut, value: viewModel.currentStep)
            .toolbar {
                if viewModel.currentStep != .intro {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") {
                            withAnimation {
                                if viewModel.currentStep == .confirmation {
                                    if viewModel.vinText.isEmpty {
                                        viewModel.currentStep = .makeModelEntry
                                    } else {
                                        viewModel.currentStep = .vinEntry
                                    }
                                } else if viewModel.currentStep == .welcome {
                                    viewModel.currentStep = .intro
                                } else {
                                    viewModel.currentStep = .welcome
                                }
                            }
                        }
                    }
                }
            }
        }
    }

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
                withAnimation { viewModel.currentStep = .welcome }
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

    private var welcomeView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "car.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.appAccent)

            VStack(spacing: 12) {
                Text("AskMyCar")
                    .font(.largeTitle.bold())

                Text("Your AI-powered vehicle assistant")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                Button {
                    withAnimation { viewModel.currentStep = .vinEntry }
                } label: {
                    Label("Enter VIN", systemImage: "barcode.viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    withAnimation { viewModel.currentStep = .makeModelEntry }
                } label: {
                    Label("Enter Make & Model", systemImage: "pencil.line")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appSecondaryBackground)
                        .foregroundStyle(Color.appPrimaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    private var confirmationView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Vehicle Ready")
                .font(.title2.bold())

            VStack(spacing: 8) {
                if !viewModel.make.isEmpty {
                    infoRow(label: "Year", value: String(viewModel.year))
                    infoRow(label: "Make", value: viewModel.make)
                    infoRow(label: "Model", value: viewModel.model)
                    if !viewModel.trim.isEmpty {
                        infoRow(label: "Trim", value: viewModel.trim)
                    }
                    if !viewModel.nickname.trimmingCharacters(in: .whitespaces).isEmpty {
                        infoRow(label: "Nickname", value: viewModel.nickname)
                    }
                }

                if let info = viewModel.decodedVINInfo {
                    infoRow(label: "VIN", value: info.vin)
                    infoRow(label: "Country", value: info.countryOfOrigin)
                    infoRow(label: "Model Year", value: info.modelYear)
                }
            }
            .padding()
            .background(Color.appSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            Button {
                let vehicle = viewModel.createVehicle(in: modelContext)
                appState.activeVehicle = vehicle

                // Create a new chat session for this vehicle
                let session = ChatSession(title: "New Chat", vehicle: vehicle)
                modelContext.insert(session)
                appState.activeSession = session

                // Dismiss sheets (garage + onboarding) when adding from garage
                appState.showGarage = false
                dismiss()
            } label: {
                Text("Start Chatting")
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

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
        .modelContainer(for: [Vehicle.self, ChatSession.self, ChatMessage.self], inMemory: true)
}
