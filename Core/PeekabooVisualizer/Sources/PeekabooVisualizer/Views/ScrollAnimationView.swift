//
//  ScrollAnimationView.swift
//  Peekaboo
//
//  A compact HUD chip with chevrons flowing in the scroll direction.
//

import PeekabooFoundation
import SwiftUI

/// Scroll feedback: a small circular chip at the scroll point with three
/// chevrons flowing along the scroll direction and an amount tag beneath.
struct ScrollAnimationView: View {
    // MARK: - Properties

    /// Scroll direction
    let direction: ScrollDirection

    /// Number of scroll units
    let amount: Int

    /// Multiplier applied to all baseline durations (larger = slower).
    let durationScale: Double

    /// Animation states
    @State private var chipScale: CGFloat = 0.7
    @State private var chipOpacity: Double = 0
    @State private var flowPhase = false

    private var chevronRotation: Angle {
        switch self.direction {
        case .up: .degrees(0)
        case .down: .degrees(180)
        case .left: .degrees(-90)
        case .right: .degrees(90)
        }
    }

    /// Unit vector of travel for the flow animation.
    private var flowVector: CGSize {
        switch self.direction {
        case .up: CGSize(width: 0, height: -1)
        case .down: CGSize(width: 0, height: 1)
        case .left: CGSize(width: -1, height: 0)
        case .right: CGSize(width: 1, height: 0)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(VisualizerTheme.hudFill)
                    .overlay(Circle().strokeBorder(VisualizerTheme.hudStroke, lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                    .frame(width: 58, height: 58)

                // Chevrons flowing along the scroll direction
                VStack(spacing: -3) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: "chevron.compact.up")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(VisualizerTheme.accent.opacity(self.chevronOpacity(index)))
                    }
                }
                .rotationEffect(self.chevronRotation)
                .offset(
                    x: self.flowVector.width * (self.flowPhase ? 5 : -5),
                    y: self.flowVector.height * (self.flowPhase ? 5 : -5))
            }

            if self.amount > 1 {
                Text("×\(self.amount)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(VisualizerTheme.hudText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .hudChip(cornerRadius: 8)
            }
        }
        .scaleEffect(self.chipScale)
        .opacity(self.chipOpacity)
        .frame(width: 100, height: 100)
        .onAppear {
            self.startAnimation()
        }
    }

    /// Chevrons brighten toward the direction of travel.
    private func chevronOpacity(_ index: Int) -> Double {
        let leading = self.flowPhase ? [1.0, 0.6, 0.3] : [0.6, 0.4, 0.2]
        return leading[safe: index] ?? 0.4
    }

    // MARK: - Methods

    private func startAnimation() {
        let scale = self.durationScale

        withAnimation(VisualizerMotion.pop(0.28 * scale)) {
            self.chipScale = 1.0
            self.chipOpacity = 1
        }

        // Two flow cycles along the scroll direction
        withAnimation(
            VisualizerMotion.glide(0.22 * scale)
                .repeatCount(3, autoreverses: true)
                .delay(0.08 * scale))
        {
            self.flowPhase = true
        }

        withAnimation(VisualizerMotion.exit(0.16 * scale).delay(0.44 * scale)) {
            self.chipOpacity = 0
            self.chipScale = 0.85
        }
    }
}

// MARK: - Preview

#if DEBUG && !SWIFT_PACKAGE
#Preview("Scroll Up") {
    ScrollAnimationView(direction: .up, amount: 3, durationScale: 3.0)
        .frame(width: 150, height: 150)
        .background(Color.gray.opacity(0.3))
}

#Preview("Scroll Down") {
    ScrollAnimationView(direction: .down, amount: 5, durationScale: 3.0)
        .frame(width: 150, height: 150)
        .background(Color.gray.opacity(0.3))
}

#Preview("Scroll Right") {
    ScrollAnimationView(direction: .right, amount: 1, durationScale: 3.0)
        .frame(width: 150, height: 150)
        .background(Color.gray.opacity(0.3))
}
#endif
