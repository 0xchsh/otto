import SwiftUI

struct VehicleCard: View {
    let vehicle: Vehicle

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Vehicle image placeholder
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
            }
            .aspectRatio(2, contentMode: .fit)

            // Vehicle info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(vehicleNickname)
                        .font(.system(size: 18, weight: .semibold))

                    Image(systemName: "ellipsis.message.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appSecondaryText)

                    if vehicle.isActive {
                        Text("Active")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }

                Text(vehicle.displayName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.appSecondaryText)
            }
        }
    }

    private var vehicleNickname: String {
        vehicle.nickname ?? "\(vehicle.make) \(vehicle.model)"
    }
}

#Preview {
    VehicleCard(vehicle: Vehicle(make: "Honda", model: "CR-V", year: 2025, nickname: "Hugo"))
        .padding()
}
