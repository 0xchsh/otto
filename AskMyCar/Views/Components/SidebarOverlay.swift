import SwiftUI

struct SidebarOverlay<Content: View>: View {
    @Binding var isOpen: Bool
    @ViewBuilder let content: () -> Content

    private let sidebarFraction: CGFloat = 0.82

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let sidebarWidth = geo.size.width * sidebarFraction

            ZStack(alignment: .leading) {
                // Dim background
                if isOpen {
                    Color.black
                        .opacity(0.4 * dimProgress(sidebarWidth: sidebarWidth))
                        .ignoresSafeArea()
                        .onTapGesture { close() }
                        .transition(.opacity)
                }

                // Sidebar panel
                HStack(spacing: 0) {
                    content()
                        .frame(width: sidebarWidth)
                        .background(Color.appBackground)
                        .offset(x: sidebarOffset(sidebarWidth: sidebarWidth))

                    Spacer(minLength: 0)
                }
            }
            .gesture(dragGesture(sidebarWidth: sidebarWidth))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isOpen)
    }

    private func sidebarOffset(sidebarWidth: CGFloat) -> CGFloat {
        if isOpen {
            return min(dragOffset, 0)
        } else {
            return -sidebarWidth
        }
    }

    private func dimProgress(sidebarWidth: CGFloat) -> CGFloat {
        if isOpen {
            let progress = 1.0 + (dragOffset / sidebarWidth)
            return max(0, min(1, progress))
        }
        return 0
    }

    private func dragGesture(sidebarWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if isOpen {
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
