import SwiftUI

struct SidebarOverlay<Content: View>: View {
    @Binding var isOpen: Bool
    @ViewBuilder let content: () -> Content

    private let sidebarWidth: CGFloat = 280

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Dim background
                if isOpen {
                    Color.black
                        .opacity(0.4 * Double(dimProgress))
                        .ignoresSafeArea()
                        .onTapGesture { close() }
                        .transition(.opacity)
                }

                // Sidebar panel
                HStack(spacing: 0) {
                    content()
                        .frame(width: sidebarWidth)
                        .background(Color.appBackground)
                        .offset(x: sidebarOffset)

                    Spacer(minLength: 0)
                }
            }
        }
        .gesture(dragGesture)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isOpen)
    }

    private var sidebarOffset: CGFloat {
        if isOpen {
            return min(dragOffset, 0)
        } else {
            return -sidebarWidth
        }
    }

    private var dimProgress: CGFloat {
        if isOpen {
            let progress = 1.0 + (dragOffset / sidebarWidth)
            return max(0, min(1, progress))
        }
        return 0
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if isOpen {
                    // Only allow dragging left to close
                    if value.translation.width < 0 {
                        dragOffset = value.translation.width
                    }
                }
            }
            .onEnded { value in
                if isOpen {
                    if value.translation.width < -80 || value.predictedEndTranslation.width < -120 {
                        close()
                    }
                }
                dragOffset = 0
            }
    }

    private func close() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isOpen = false
            dragOffset = 0
        }
    }
}
