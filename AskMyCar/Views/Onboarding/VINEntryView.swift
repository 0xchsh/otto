import SwiftUI

struct VINEntryView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Enter Your VIN")
                .font(.title2.bold())

            Text("Your Vehicle Identification Number is a 17-character code found on your dashboard or door jamb.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

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
                    if let error = viewModel.vinValidationError {
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

            Button {
                viewModel.validateAndDecodeVIN()
            } label: {
                HStack {
                    if viewModel.isValidatingVIN {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Decode VIN")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.canDecodeVIN ? Color.appAccent : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!viewModel.canDecodeVIN || viewModel.isValidatingVIN)

            Button("Enter make & model instead") {
                viewModel.currentStep = .makeModelEntry
            }
            .font(.subheadline)
            .foregroundStyle(Color.appAccent)
        }
        .padding()
    }
}

#Preview {
    VINEntryView(viewModel: OnboardingViewModel())
}
