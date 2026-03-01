import SwiftUI
import SwiftData

struct ChatHistoryRow: View {
    let session: ChatSession
    let isActive: Bool

    var body: some View {
        Text(session.previewText)
            .font(.body)
            .foregroundStyle(Color.appPrimaryText)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isActive
                ? Color.appAccent.opacity(0.12)
                : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
