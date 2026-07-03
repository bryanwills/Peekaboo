//
//  MenuNavigationView.swift
//  Peekaboo
//
//  A breadcrumb HUD chip that lights up each menu segment in sequence.
//

import SwiftUI

/// Menu-navigation feedback: the traversed path renders as a breadcrumb and
/// each segment illuminates in order, tracing the route through the menus.
struct MenuNavigationView: View {
    let menuPath: [String]
    let duration: TimeInterval

    @State private var chipScale: CGFloat = 0.94
    @State private var chipOpacity: Double = 0
    @State private var litCount = 0

    init(menuPath: [String], duration: TimeInterval = 1.5) {
        self.menuPath = menuPath
        self.duration = duration
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(self.menuPath.enumerated()), id: \.offset) { index, segment in
                HStack(spacing: 8) {
                    MenuSegmentView(
                        title: segment,
                        state: self.segmentState(index))

                    if index < self.menuPath.count - 1 {
                        Image(systemName: "chevron.compact.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VisualizerTheme.hudTextSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .hudChip(cornerRadius: 16)
        .scaleEffect(self.chipScale)
        .opacity(self.chipOpacity)
        .onAppear {
            withAnimation(VisualizerMotion.pop()) {
                self.chipScale = 1.0
                self.chipOpacity = 1
            }
        }
        .task {
            await self.traverseBreadcrumb()
        }
    }

    private func segmentState(_ index: Int) -> MenuSegmentView.SegmentState {
        if index == self.litCount - 1 {
            .active
        } else if index < self.litCount {
            .visited
        } else {
            .pending
        }
    }

    /// Illuminates segments in traversal order. Sequenced in real time because
    /// the segment states are discrete and would collapse under delayed animations.
    private func traverseBreadcrumb() async {
        let step = min(0.25, (self.duration * 0.5) / Double(max(self.menuPath.count, 1)))

        try? await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
        for index in self.menuPath.indices {
            guard !Task.isCancelled else { return }
            withAnimation(VisualizerMotion.pop(0.28)) {
                self.litCount = index + 1
            }
            try? await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
        }

        let holdRemainder = max(self.duration - 0.6 - Double(self.menuPath.count) * step, 0.2)
        try? await Task.sleep(nanoseconds: UInt64(holdRemainder * 1_000_000_000))
        guard !Task.isCancelled else { return }
        withAnimation(VisualizerMotion.exit(0.35)) {
            self.chipOpacity = 0
            self.chipScale = 0.97
        }
    }
}

/// One breadcrumb segment.
private struct MenuSegmentView: View {
    enum SegmentState {
        case pending
        case visited
        case active
    }

    let title: String
    let state: SegmentState

    var body: some View {
        Text(self.title)
            .font(.system(size: 14, weight: self.state == .active ? .semibold : .medium, design: .rounded))
            .foregroundStyle(self.textColor)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(self.state == .active ? VisualizerTheme.accent.opacity(0.28) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                self.state == .active ? VisualizerTheme.accent.opacity(0.7) : Color.clear,
                                lineWidth: 1)))
            .scaleEffect(self.state == .pending ? 0.96 : 1.0)
            .opacity(self.state == .pending ? 0.45 : 1.0)
    }

    private var textColor: Color {
        switch self.state {
        case .pending: VisualizerTheme.hudTextSecondary
        case .visited: VisualizerTheme.hudText.opacity(0.75)
        case .active: VisualizerTheme.hudText
        }
    }
}

#if DEBUG && !SWIFT_PACKAGE
#Preview {
    VStack(spacing: 40) {
        MenuNavigationView(menuPath: ["File", "New", "Project"], duration: 3.0)
        MenuNavigationView(menuPath: ["Edit", "Find", "Find and Replace…"], duration: 3.0)
    }
    .frame(width: 600, height: 250)
    .background(Color.gray.opacity(0.3))
}
#endif
