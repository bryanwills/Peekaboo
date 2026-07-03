//
//  ScreenshotFlashView.swift
//  Peekaboo
//
//  A viewfinder capture: corner brackets snap in with a soft shutter veil.
//

import SwiftUI

/// Screenshot feedback: viewfinder corner brackets snap onto the captured
/// region while a brief veil flashes, reading as a camera shutter.
struct ScreenshotFlashView: View {
    // MARK: - Properties

    /// Whether to show the ghost easter egg
    let showGhost: Bool

    /// Effect intensity (0.0 to 1.0)
    let intensity: Double

    /// Animation state
    @State private var veilOpacity: Double = 0
    @State private var bracketProgress: CGFloat = 0
    @State private var bracketOpacity: Double = 0
    @State private var ghostScale: Double = 0.5
    @State private var ghostOffset: CGFloat = 0
    @State private var ghostOpacity: Double = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            // Shutter veil
            Color.white
                .opacity(self.veilOpacity * self.intensity * 0.18)
                .ignoresSafeArea()

            // Viewfinder corner brackets
            CornerBracketsShape(inset: 12, armLength: 30)
                .trim(from: 0, to: self.bracketProgress)
                .stroke(
                    Color.white.opacity(0.9),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .shadow(color: VisualizerTheme.accent.opacity(0.6), radius: 6)
                .opacity(self.bracketOpacity)

            // Ghost easter egg (every 100th screenshot)
            if self.showGhost {
                Text("👻")
                    .font(.system(size: 52))
                    .scaleEffect(self.ghostScale)
                    .offset(y: self.ghostOffset)
                    .opacity(self.ghostOpacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            self.startCaptureAnimation()
        }
    }

    // MARK: - Methods

    private func startCaptureAnimation() {
        // Brackets snap onto the captured region
        withAnimation(VisualizerMotion.enter(0.05)) {
            self.bracketOpacity = 1
        }
        withAnimation(VisualizerMotion.enter(0.16)) {
            self.bracketProgress = 1.0
        }

        // Shutter veil pulses once
        withAnimation(VisualizerMotion.enter(0.08).delay(0.08)) {
            self.veilOpacity = 1.0
        }
        withAnimation(VisualizerMotion.exit(0.12).delay(0.16)) {
            self.veilOpacity = 0
        }

        // Brackets linger briefly, then dissolve
        withAnimation(VisualizerMotion.exit(0.12).delay(0.22)) {
            self.bracketOpacity = 0
        }

        // Ghost floats up and fades
        if self.showGhost {
            withAnimation(VisualizerMotion.pop(0.35).delay(0.05)) {
                self.ghostScale = 1.0
                self.ghostOpacity = 0.9
            }
            withAnimation(VisualizerMotion.glide(0.5).delay(0.1)) {
                self.ghostOffset = -28
            }
            withAnimation(VisualizerMotion.exit(0.25).delay(0.45)) {
                self.ghostOpacity = 0
                self.ghostScale = 1.1
            }
        }
    }
}

// MARK: - Preview

#if DEBUG && !SWIFT_PACKAGE
#Preview("Capture") {
    ScreenshotFlashView(showGhost: false, intensity: 1.0)
        .frame(width: 400, height: 300)
        .background(Color.gray.opacity(0.3))
}

#Preview("With Ghost") {
    ScreenshotFlashView(showGhost: true, intensity: 1.0)
        .frame(width: 400, height: 300)
        .background(Color.gray.opacity(0.3))
}
#endif
