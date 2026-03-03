import SwiftUI

struct VehicleCard: View {
    let vehicle: Vehicle
    var onChat: () -> Void = {}
    var onRename: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Vehicle image (CGI render from imagin.studio)
            AsyncImage(url: vehicle.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding(.top, -16)
                case .failure:
                    vehicleImagePlaceholder
                default:
                    vehicleImagePlaceholder
                        .overlay {
                            ProgressView()
                        }
                }
            }

            // Vehicle info
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(vehicleNickname)
                            .font(.system(size: 18, weight: .semibold))

                        Menu {
                            Button {
                                onRename()
                            } label: {
                                Label("Rename Vehicle", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                Label("Delete Vehicle", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.appSecondaryText)
                        }
                    }

                    Text(vehicle.displayName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.appSecondaryText)
                }

                Spacer()

                Button {
                    onChat()
                } label: {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(.systemGray))
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 8)
        }
    }

    private var vehicleImagePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(.systemGray5), Color(.systemGray6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "car.side.fill")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(Color(.systemGray3))
                .scaleEffect(x: -1)
        }
        .aspectRatio(2, contentMode: .fit)
    }

    private var vehicleNickname: String {
        if let nickname = vehicle.nickname, !nickname.isEmpty {
            return nickname
        }
        let makeModel = "\(vehicle.make) \(vehicle.model)".trimmingCharacters(in: .whitespaces)
        return makeModel.isEmpty ? "My Vehicle" : makeModel
    }
}

#Preview {
    VehicleCard(vehicle: Vehicle(make: "Honda", model: "CR-V", year: 2025, nickname: "Hugo"))
        .padding()
}
