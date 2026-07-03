//
//  ClickAnimationView.swift
//  Peekaboo
//
//  A targeting reticle that locks onto the click point and pulses on impact.
//

import PeekabooFoundation
import SwiftUI

/// Click feedback: an outer ring contracts onto the point, a center dot pops,
/// and an impact pulse expands outward. Double-click pulses twice; right-click
/// uses a dashed ring to hint at a context menu.
struct ClickAnimationView: View {
    // MARK: - Properties

    /// Type of click
    let clickType: ClickType

    /// Multiplier applied to all baseline durations (larger = slower).
    let durationScale: Double

    /// Animation state
    @State private var ringDiameter: CGFloat = 130
    @State private var ringOpacity: Double = 0
    @State private var dotScale: CGFloat = 0.2
    @State private var dotOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var reticleOpacity: Double = 1

    private var tint: Color {
        self.clickType == .right ? VisualizerTheme.accentSecondary : VisualizerTheme.accent
    }

    private var ringStyle: StrokeStyle {
        switch self.clickType {
        case .right:
            StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [7, 6])
        case .single, .double:
            StrokeStyle(lineWidth: 2.5, lineCap: .round)
        }
    }

    private var pulseDelays: [Double] {
        self.clickType == .double ? [0.22, 0.36] : [0.22]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Soft bloom behind the impact point
            Circle()
                .fill(
                    RadialGradient(
                        colors: [self.tint.opacity(0.45), self.tint.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 44))
                .frame(width: 88, height: 88)
                .opacity(self.glowOpacity)

            // Targeting ring that contracts onto the point
            Circle()
                .stroke(self.tint, style: self.ringStyle)
                .frame(width: self.ringDiameter, height: self.ringDiameter)
                .opacity(self.ringOpacity)

            // Impact pulses expanding outward
            ForEach(Array(self.pulseDelays.enumerated()), id: \.offset) { _, delay in
                ImpactPulseView(tint: self.tint, delay: delay * self.durationScale, duration: 0.3 * self.durationScale)
            }

            // Center dot
            Circle()
                .fill(self.tint)
                .frame(width: 9, height: 9)
                .scaleEffect(self.dotScale)
                .opacity(self.dotOpacity)
                .shadow(color: self.tint.opacity(0.8), radius: 6)
        }
        .opacity(self.reticleOpacity)
        .frame(width: 320, height: 320)
        .onAppear {
            self.startAnimation()
        }
    }

    // MARK: - Methods

    private func startAnimation() {
        let scale = self.durationScale

        // Ring locks onto the target
        withAnimation(VisualizerMotion.enter(0.1 * scale)) {
            self.ringOpacity = 1
        }
        withAnimation(VisualizerMotion.enter(0.26 * scale)) {
            self.ringDiameter = 46
        }

        // Center dot pops with a glow bloom
        withAnimation(VisualizerMotion.pop(0.3 * scale).delay(0.06 * scale)) {
            self.dotScale = 1.0
            self.dotOpacity = 1
        }
        withAnimation(VisualizerMotion.enter(0.2 * scale).delay(0.16 * scale)) {
            self.glowOpacity = 1
        }
        withAnimation(VisualizerMotion.exit(0.18 * scale).delay(0.34 * scale)) {
            self.glowOpacity = 0
        }

        // Everything dissolves at the end
        withAnimation(VisualizerMotion.exit(0.14 * scale).delay(0.31 * scale)) {
            self.reticleOpacity = 0
            self.dotScale = 0.6
        }
    }
}

/// A single expanding impact ring.
private struct ImpactPulseView: View {
    let tint: Color
    let delay: Double
    let duration: Double

    @State private var pulseScale: CGFloat = 0.3
    @State private var pulseOpacity: Double = 0

    var body: some View {
        Circle()
            .stroke(self.tint, lineWidth: 2)
            .frame(width: 150, height: 150)
            .scaleEffect(self.pulseScale)
            .opacity(self.pulseOpacity)
            .onAppear {
                withAnimation(VisualizerMotion.enter(0.05).delay(self.delay)) {
                    self.pulseOpacity = 0.9
                }
                withAnimation(VisualizerMotion.enter(self.duration).delay(self.delay)) {
                    self.pulseScale = 1.0
                }
                withAnimation(VisualizerMotion.exit(self.duration * 0.7).delay(self.delay + self.duration * 0.3)) {
                    self.pulseOpacity = 0
                }
            }
    }
}

// MARK: - Preview

#if DEBUG && !SWIFT_PACKAGE
#Preview("Single Click") {
    ClickAnimationView(clickType: .single, durationScale: 3.0)
        .frame(width: 320, height: 320)
        .background(Color.gray.opacity(0.3))
}

#Preview("Double Click") {
    ClickAnimationView(clickType: .double, durationScale: 3.0)
        .frame(width: 320, height: 320)
        .background(Color.gray.opacity(0.3))
}

#Preview("Right Click") {
    ClickAnimationView(clickType: .right, durationScale: 3.0)
        .frame(width: 320, height: 320)
        .background(Color.gray.opacity(0.3))
}
#endif
