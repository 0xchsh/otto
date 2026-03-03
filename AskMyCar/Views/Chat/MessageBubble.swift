import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    var isStreaming: Bool = false

    private var isUser: Bool { message.role == .user }

    private var formattedContent: Text {
        if let attributed = try? AttributedString(markdown: message.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attributed)
        }
        return Text(message.content)
    }

    private var hasImages: Bool {
        guard let imageData = message.imageData else { return false }
        return !imageData.isEmpty
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                if hasImages, let imageDataArray = message.imageData {
                    HStack(spacing: 6) {
                        ForEach(Array(imageDataArray.enumerated()), id: \.offset) { _, data in
                            if let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }

                if !message.content.isEmpty {
                    textContent
                        .padding(12)
                        .background(isUser ? Color.userBubble : Color.assistantBubble)
                        .foregroundStyle(isUser ? .white : Color.appPrimaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var textContent: some View {
        formattedContent
            .contentTransition(.interpolate)
            .animation(isStreaming ? .easeIn(duration: 0.15) : nil, value: message.content)
    }
}

#Preview {
    VStack {
        MessageBubble(message: ChatMessage(role: .user, content: "What oil does my car need?"))
        MessageBubble(message: ChatMessage(role: .assistant, content: "Your vehicle uses 0W-20 synthetic oil. The oil capacity is approximately 5.7 quarts with filter change."))
    }
}
