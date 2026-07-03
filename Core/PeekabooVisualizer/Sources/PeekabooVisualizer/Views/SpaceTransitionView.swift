//
//  SpaceTransitionView.swift
//  Peekaboo
//
//  A macOS-style Spaces indicator: the active dot slides to the new desktop.
//

import SwiftUI

/// Space-switch feedback: a compact HUD chip with a dot per desktop; the
/// active dot glides from the old space to the new one and the label updates.
struct SpaceTransitionView: View {
    let fromSpace: Int
    let toSpace: Int
    let direction: SpaceDirection
    let duration: TimeInterval

    @State private var chipScale: CGFloat = 0.92
    @State private var chipOpacity: Double = 0
    @State private var activeSpace: Int
    @State private var labelSpace: Int

    /// Cap the dot row; beyond this the label alone tells the story.
    private static let maxDots = 10

    init(from: Int, to: Int, direction: SpaceDirection, duration: TimeInterval = 1.0) {
        self.fromSpace = from
        self.toSpace = to
        self.direction = direction
        self.duration = duration
        self._activeSpace = State(initialValue: from)
        self._labelSpace = State(initialValue: from)
    }

    private var spaceCount: Int {
        max(self.fromSpace, self.toSpace)
    }

    private var showsDots: Bool {
        self.spaceCount <= Self.maxDots && self.fromSpace >= 1 && self.toSpace >= 1
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: self.direction.glyphName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VisualizerTheme.accent)

                Text("Desktop \(self.labelSpace)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(VisualizerTheme.hudText)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            // The label must never truncate to "Deskto…", even under a
            // compressed width proposal from the hosting window.
            .fixedSize()

            if self.showsDots {
                HStack(spacing: 9) {
                    ForEach(1...self.spaceCount, id: \.self) { space in
                        Circle()
                            .fill(
                                space == self.activeSpace
                                    ? VisualizerTheme.accent
                                    : Color.white.opacity(0.28))
                            .frame(width: 8, height: 8)
                            .scaleEffect(space == self.activeSpace ? 1.3 : 1.0)
                            .shadow(
                                color: space == self.activeSpace
                                    ? VisualizerTheme.accent.opacity(0.8)
                                    : .clear,
                                radius: 5)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .hudChip(cornerRadius: 18)
        .scaleEffect(self.chipScale)
        .opacity(self.chipOpacity)
        .onAppear {
            withAnimation(VisualizerMotion.pop()) {
                self.chipScale = 1.0
                self.chipOpacity = 1
            }
        }
        .task {
            await self.animateTransition()
        }
    }

    /// The active dot hops to the destination space mid-display. Sequenced in
    /// real time because the dot index is discrete state.
    private func animateTransition() async {
        try? await Task.sleep(nanoseconds: UInt64(self.duration * 0.25 * 1_000_000_000))
        guard !Task.isCancelled else { return }
        withAnimation(VisualizerMotion.settle(0.5)) {
            self.activeSpace = self.toSpace
            self.labelSpace = self.toSpace
        }

        let holdRemainder = max(self.duration * 0.75 - 0.35, 0.25)
        try? await Task.sleep(nanoseconds: UInt64(holdRemainder * 1_000_000_000))
        guard !Task.isCancelled else { return }
        withAnimation(VisualizerMotion.exit(0.3)) {
            self.chipOpacity = 0
            self.chipScale = 0.96
        }
    }
}

// MARK: - SpaceDirection styling

extension SpaceDirection {
    var glyphName: String {
        switch self {
        case .left: "arrow.left"
        case .right: "arrow.right"
        case .up: "arrow.up"
        case .down: "arrow.down"
        }
    }
}

#if DEBUG && !SWIFT_PACKAGE
#Preview {
    VStack(spacing: 40) {
        SpaceTransitionView(from: 1, to: 3, direction: .right, duration: 3.0)
        SpaceTransitionView(from: 4, to: 2, direction: .left, duration: 3.0)
    }
    .frame(width: 400, height: 300)
    .background(Color.gray.opacity(0.3))
}
#endif
