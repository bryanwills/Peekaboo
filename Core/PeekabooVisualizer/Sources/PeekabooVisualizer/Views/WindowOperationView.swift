//
//  WindowOperationView.swift
//  Peekaboo
//
//  A window outline with a glyph badge; each operation gets its own motion.
//

import SwiftUI

/// Window-operation feedback: the window's outline animates the operation
/// (contract for close, squash for minimize, expand for maximize…) while a
/// small badge names it. Accent color throughout; red only for close.
struct WindowOperationView: View {
    let operation: WindowOperation
    let windowRect: CGRect
    let duration: TimeInterval

    @State private var frameScale: CGSize = .init(width: 1, height: 1)
    @State private var frameOpacity: Double = 0
    @State private var frameOffset: CGFloat = 0
    @State private var badgeScale: CGFloat = 0.5
    @State private var badgeOpacity: Double = 0
    @State private var bracketsOpacity: Double = 0
    @State private var bracketsInset: CGFloat = 18

    init(operation: WindowOperation, windowRect: CGRect, duration: TimeInterval = 0.5) {
        self.operation = operation
        self.windowRect = windowRect
        self.duration = duration
    }

    private var tint: Color {
        self.operation == .close ? VisualizerTheme.destructive : VisualizerTheme.accent
    }

    var body: some View {
        ZStack {
            // Window outline
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(self.tint, lineWidth: 2.5)
                .frame(width: self.windowRect.width, height: self.windowRect.height)
                .scaleEffect(x: self.frameScale.width, y: self.frameScale.height, anchor: self.scaleAnchor)
                .offset(y: self.frameOffset)
                .opacity(self.frameOpacity)
                .shadow(color: self.tint.opacity(0.35), radius: 12)

            // Corner brackets for resize-style operations
            if self.showsBrackets {
                CornerBracketsShape(inset: self.bracketsInset, armLength: 24)
                    .stroke(self.tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: self.windowRect.width, height: self.windowRect.height)
                    .opacity(self.bracketsOpacity)
            }

            // Operation badge at the top edge of the window
            GlyphBadgeView(systemName: self.glyphName, tint: self.tint)
                .scaleEffect(self.badgeScale)
                .opacity(self.badgeOpacity)
                .offset(y: -self.windowRect.height / 2)
        }
        .onAppear {
            self.animateOperation()
        }
    }

    private var showsBrackets: Bool {
        self.operation == .resize || self.operation == .setBounds
    }

    private var scaleAnchor: UnitPoint {
        self.operation == .minimize ? .bottom : .center
    }

    private var glyphName: String {
        switch self.operation {
        case .close: "xmark"
        case .minimize: "arrow.down.to.line"
        case .maximize: "arrow.up.left.and.arrow.down.right"
        case .move: "arrow.up.and.down.and.arrow.left.and.right"
        case .resize: "square.resize"
        case .setBounds: "rectangle.dashed"
        case .focus: "scope"
        }
    }

    private func animateOperation() {
        // Outline and badge arrive together
        withAnimation(VisualizerMotion.enter(0.18)) {
            self.frameOpacity = 1
        }
        withAnimation(VisualizerMotion.pop().delay(0.08)) {
            self.badgeScale = 1.0
            self.badgeOpacity = 1
        }

        let exitDelay = max(self.duration - 0.3, 0.4)

        switch self.operation {
        case .close:
            withAnimation(VisualizerMotion.exit(self.duration * 0.55).delay(0.25)) {
                self.frameScale = CGSize(width: 0.94, height: 0.94)
            }

        case .minimize:
            withAnimation(VisualizerMotion.glide(self.duration * 0.55).delay(0.25)) {
                self.frameScale = CGSize(width: 0.92, height: 0.12)
                self.frameOffset = 8
            }

        case .maximize, .focus:
            withAnimation(VisualizerMotion.settle(0.5).delay(0.2)) {
                self.frameScale = CGSize(width: 1.03, height: 1.03)
            }

        case .move:
            withAnimation(VisualizerMotion.settle(0.4).delay(0.2)) {
                self.frameOffset = -8
            }
            withAnimation(VisualizerMotion.settle(0.4).delay(0.5)) {
                self.frameOffset = 0
            }

        case .resize, .setBounds:
            self.bracketsOpacity = 1
            withAnimation(VisualizerMotion.settle(0.45).delay(0.2)) {
                self.bracketsInset = 8
            }
        }

        // Dissolve
        withAnimation(VisualizerMotion.exit(0.3).delay(exitDelay)) {
            self.frameOpacity = 0
            self.badgeOpacity = 0
            self.bracketsOpacity = 0
        }
    }
}

#if DEBUG && !SWIFT_PACKAGE
#Preview {
    VStack(spacing: 50) {
        WindowOperationView(
            operation: .close,
            windowRect: CGRect(x: 0, y: 0, width: 300, height: 200),
            duration: 2.0)
            .frame(width: 400, height: 300)
            .background(Color.gray.opacity(0.3))

        WindowOperationView(
            operation: .resize,
            windowRect: CGRect(x: 0, y: 0, width: 300, height: 200),
            duration: 2.0)
            .frame(width: 400, height: 300)
            .background(Color.gray.opacity(0.3))
    }
}
#endif
