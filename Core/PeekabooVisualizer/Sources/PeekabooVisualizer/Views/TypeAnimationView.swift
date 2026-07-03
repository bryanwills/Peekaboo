//
//  TypeAnimationView.swift
//  Peekaboo
//
//  A caption-style HUD pill that streams the typed text with a live caret.
//

import PeekabooFoundation
import SwiftUI

/// Typing feedback: the actual keystrokes stream into a caption pill at the
/// bottom of the screen, with non-printing keys rendered as accent glyphs and
/// a blinking caret marking the insertion point.
struct TypeAnimationView: View {
    // MARK: - Properties

    /// Keys being typed
    let keys: [String]

    /// Typing cadence metadata
    let cadence: TypingCadence?

    /// Multiplier applied to all baseline durations (larger = slower).
    let durationScale: Double

    /// How long the overlay window stays on screen; the key stream must finish within it.
    let displayDuration: TimeInterval

    /// Number of keys revealed so far
    @State private var typedCount = 0

    /// Caret blink state
    @State private var caretVisible = true

    /// Chip entrance/exit state
    @State private var chipScale: CGFloat = 0.92
    @State private var chipOpacity: Double = 0

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(VisualizerTheme.hudTextSecondary)

            HStack(spacing: 3) {
                self.typedText
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .foregroundStyle(VisualizerTheme.hudText)
                    .lineLimit(1)
                    .truncationMode(.head)

                // Caret
                RoundedRectangle(cornerRadius: 1)
                    .fill(VisualizerTheme.accent)
                    .frame(width: 2.5, height: 21)
                    .opacity(self.caretVisible ? 1 : 0.15)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: 620)
        .fixedSize(horizontal: true, vertical: true)
        .hudChip(cornerRadius: 24)
        .scaleEffect(self.chipScale)
        .opacity(self.chipOpacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onAppear {
            withAnimation(VisualizerMotion.pop()) {
                self.chipScale = 1.0
                self.chipOpacity = 1
            }
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                self.caretVisible = false
            }
        }
        .task {
            await self.streamKeys()
        }
    }

    /// The revealed keys as styled text; non-printing keys become accent glyphs.
    private var typedText: Text {
        self.keys.prefix(self.typedCount).reduce(Text(verbatim: "")) { text, key in
            if let glyph = VisualizerKeyGlyphs.inlineSymbol(for: key) {
                text + Text(glyph).foregroundStyle(VisualizerTheme.accent)
            } else {
                text + Text(verbatim: key)
            }
        }
    }

    // MARK: - Methods

    /// Per-key reveal interval: the cadence-scaled pace, compressed if needed
    /// so the full stream (plus hold and fade) fits inside the overlay window.
    /// Callers pass fixed display durations, so long strings must speed up
    /// rather than get cut off mid-stream.
    static func keyInterval(
        cadence: TypingCadence?,
        durationScale: Double,
        keyCount: Int,
        displayDuration: TimeInterval) -> TimeInterval
    {
        let baseline: TimeInterval = switch cadence {
        case let .human(wordsPerMinute) where wordsPerMinute > 0:
            // 1 word ≈ 5 characters
            60.0 / (Double(wordsPerMinute) * 5.0)
        case let .fixed(milliseconds) where milliseconds > 0:
            Double(milliseconds) / 1000.0
        default:
            0.045
        }
        let paced = min(max(baseline, 0.02), 0.3) * durationScale

        // Reserve room for the trailing hold + fade, but never most of the window.
        let reserve = min(0.65 * durationScale, displayDuration * 0.3)
        let streamBudget = max(displayDuration - reserve, 0.5)
        let fitted = streamBudget / Double(max(keyCount, 1))

        return min(paced, fitted)
    }

    private func streamKeys() async {
        let interval = Self.keyInterval(
            cadence: self.cadence,
            durationScale: self.durationScale,
            keyCount: self.keys.count,
            displayDuration: self.displayDuration)
        let nanoseconds = UInt64(interval * 1_000_000_000)
        for index in self.keys.indices {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: nanoseconds)
            withAnimation(VisualizerMotion.enter(0.08)) {
                self.typedCount = index + 1
            }
        }

        // Hold briefly, then hand the fade to the overlay window
        try? await Task.sleep(nanoseconds: UInt64(0.4 * self.durationScale * 1_000_000_000))
        guard !Task.isCancelled else { return }
        withAnimation(VisualizerMotion.exit(0.25 * self.durationScale)) {
            self.chipOpacity = 0
            self.chipScale = 0.96
        }
    }
}

// MARK: - Preview

#if DEBUG && !SWIFT_PACKAGE
#Preview("Sentence") {
    TypeAnimationView(
        keys: "Hello World".map(String.init),
        cadence: .human(wordsPerMinute: 140),
        durationScale: 1.0,
        displayDuration: 3.0)
        .frame(width: 680, height: 140)
        .background(Color.gray.opacity(0.3))
}

#Preview("Special Keys") {
    TypeAnimationView(
        keys: ["T", "e", "s", "t", "{tab}", "4", "2", "{return}"],
        cadence: .fixed(milliseconds: 60),
        durationScale: 1.0,
        displayDuration: 3.0)
        .frame(width: 680, height: 140)
        .background(Color.gray.opacity(0.3))
}
#endif
