//
//  HotkeyOverlayView.swift
//  Peekaboo
//
//  A chord of macOS-style keycaps that press down in sequence.
//

import SwiftUI

/// Hotkey feedback: the pressed chord appears as real keycaps in a HUD chip,
/// each key pressing down in order like an actual keystroke.
struct HotkeyOverlayView: View {
    let keys: [String]
    let duration: TimeInterval

    @State private var chipScale: CGFloat = 0.9
    @State private var chipOpacity: Double = 0
    @State private var pressedKeys: Set<Int> = []

    init(keys: [String], duration: TimeInterval = 1.5) {
        self.keys = keys
        self.duration = duration
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(self.keys.enumerated()), id: \.offset) { index, key in
                KeycapView(key: key, isPressed: self.pressedKeys.contains(index))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
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
            await self.pressChord()
        }
    }

    /// Presses each key in sequence, holds the chord, then releases together.
    /// Discrete state changes are sequenced in real time; delayed animations
    /// would collapse them into the final frame.
    private func pressChord() async {
        let pressStagger = min(0.12, self.duration * 0.08)

        await self.sleep(0.15)
        for index in self.keys.indices {
            guard !Task.isCancelled else { return }
            withAnimation(VisualizerMotion.pop(0.22)) {
                _ = self.pressedKeys.insert(index)
            }
            await self.sleep(pressStagger)
        }

        let holdUntilRelease = max(self.duration - 0.6 - Double(self.keys.count) * pressStagger, 0.3)
        await self.sleep(holdUntilRelease)
        guard !Task.isCancelled else { return }
        withAnimation(VisualizerMotion.settle(0.3)) {
            self.pressedKeys.removeAll()
        }

        await self.sleep(0.3)
        guard !Task.isCancelled else { return }
        withAnimation(VisualizerMotion.exit(0.3)) {
            self.chipOpacity = 0
            self.chipScale = 0.95
        }
    }

    private func sleep(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

#if DEBUG && !SWIFT_PACKAGE
#Preview {
    VStack(spacing: 40) {
        HotkeyOverlayView(keys: ["Cmd", "C"], duration: 3.0)
        HotkeyOverlayView(keys: ["Cmd", "Shift", "T"], duration: 3.0)
        HotkeyOverlayView(keys: ["Ctrl", "Option", "Space"], duration: 3.0)
    }
    .frame(width: 500, height: 400)
    .background(Color.gray.opacity(0.3))
}
#endif
