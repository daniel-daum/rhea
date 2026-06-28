import SwiftUI
import AppKit

/// A horizontal split container with a draggable divider that shows ↔ resize cursor on hover.
/// Replaces HSplitView to give us explicit control over the handle appearance and cursor.
struct ResizableHSplit<Left: View, Right: View>: View {
    let minLeft:  CGFloat
    let minRight: CGFloat
    @ViewBuilder var left:  () -> Left
    @ViewBuilder var right: () -> Right

    @State private var leftWidth: CGFloat? = nil

    init(
        minLeft:  CGFloat = 190,
        minRight: CGFloat = 260,
        @ViewBuilder left:  @escaping () -> Left,
        @ViewBuilder right: @escaping () -> Right
    ) {
        self.minLeft  = minLeft
        self.minRight = minRight
        self.left     = left
        self.right    = right
    }

    var body: some View {
        GeometryReader { geo in
            let total    = geo.size.width
            let safeLeft = clamp(leftWidth ?? total * 0.44, lo: minLeft, hi: total - minRight - 8)

            HStack(spacing: 0) {
                left()
                    .frame(width: safeLeft)
                    .frame(maxHeight: .infinity)

                SplitHandle(leftWidth: Binding(
                    get: { safeLeft },
                    set: { leftWidth = clamp($0, lo: minLeft, hi: total - minRight - 8) }
                ))

                right()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func clamp(_ val: CGFloat, lo: CGFloat, hi: CGFloat) -> CGFloat {
        max(lo, min(hi, val))
    }
}

// MARK: - Divider handle

private struct SplitHandle: View {
    @Binding var leftWidth: CGFloat
    @State private var isHovered  = false
    @State private var isDragging = false
    @State private var startWidth: CGFloat = 0

    var body: some View {
        ZStack {
            // The actual 1-pt separator line
            Rectangle()
                .fill(Color.primary.opacity(active ? 0.28 : 0.1))
                .frame(width: 1)
                .animation(.easeInOut(duration: 0.12), value: active)

            // Grip dots
            VStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle()
                        .fill(Color.primary.opacity(active ? 0.45 : 0.2))
                        .frame(width: 3, height: 3)
                }
            }
            .animation(.easeInOut(duration: 0.12), value: active)
        }
        .frame(width: 8)          // wider hit area than the visible 1-pt line
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active:
                isHovered = true
                NSCursor.resizeLeftRight.set()
            case .ended:
                isHovered = false
                if !isDragging { NSCursor.arrow.set() }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { v in
                    if !isDragging {
                        isDragging = true
                        startWidth = leftWidth
                    }
                    // Hold the resize cursor through the drag, even if the
                    // pointer strays off the thin handle.
                    NSCursor.resizeLeftRight.set()
                    leftWidth = startWidth + v.translation.width
                }
                .onEnded { _ in
                    isDragging = false
                    if !isHovered { NSCursor.arrow.set() }
                }
        )
    }

    private var active: Bool { isHovered || isDragging }
}
