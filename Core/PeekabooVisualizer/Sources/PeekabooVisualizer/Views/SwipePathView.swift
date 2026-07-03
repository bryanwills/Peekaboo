//
//  SwipePathView.swift
//  Peekaboo
//
//  A drag comet with press and release rings marking the gesture endpoints.
//

import SwiftUI

/// Swipe/drag feedback: a press ring marks touch-down, a comet traces the
/// gesture, and a release ring with a direction chevron marks touch-up.
/// Points are window-local SwiftUI coordinates (top-left origin).
struct SwipePathView: View {
    let fromPoint: CGPoint
    let toPoint: CGPoint
    let duration: TimeInterval

    @State private var progress: CGFloat = 0
    @State private var pathOpacity: Double = 1
    @State private var pressScale: CGFloat = 0.3
    @State private var pressOpacity: Double = 0
    @State private var releaseScale: CGFloat = 0.3
    @State private var releaseOpacity: Double = 0
    @State private var chevronOpacity: Double = 0

    init(from: CGPoint, to: CGPoint, duration: TimeInterval = 0.5) {
        self.fromPoint = from
        self.toPoint = to
        self.duration = duration
    }

    var body: some View {
        ZStack {
            // Soft afterglow beneath the drag path
            self.dragPath
                .trim(from: 0, to: self.progress)
                .stroke(
                    VisualizerTheme.accent.opacity(0.3),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .blur(radius: 6)
                .opacity(self.pathOpacity)

            // Drag stroke — thicker than the mouse trail because the button is held
            self.dragPath
                .trim(from: 0, to: self.progress)
                .stroke(
                    VisualizerTheme.accentGradient,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .opacity(self.pathOpacity)

            // Press ring at the start point
            Circle()
                .stroke(VisualizerTheme.accent, lineWidth: 2.5)
                .frame(width: 40, height: 40)
                .scaleEffect(self.pressScale)
                .opacity(self.pressOpacity)
                .position(self.fromPoint)

            // Comet head while dragging
            Circle()
                .fill(.white)
                .frame(width: 9, height: 9)
                .shadow(color: VisualizerTheme.accent.opacity(0.9), radius: 8)
                .position(self.headPosition)
                .opacity(self.pathOpacity)

            // Release ring and direction chevron at the end point
            ZStack {
                Circle()
                    .stroke(VisualizerTheme.accentSecondary, lineWidth: 2.5)
                    .frame(width: 44, height: 44)
                    .scaleEffect(self.releaseScale)
                    .opacity(self.releaseOpacity)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(VisualizerTheme.accentSecondary)
                    .rotationEffect(self.travelAngle)
                    .opacity(self.chevronOpacity)
            }
            .position(self.toPoint)
        }
        .onAppear {
            self.animateSwipe()
        }
    }

    private var dragPath: Path {
        Path { path in
            path.move(to: self.fromPoint)
            path.addLine(to: self.toPoint)
        }
    }

    private var headPosition: CGPoint {
        CGPoint(
            x: self.fromPoint.x + (self.toPoint.x - self.fromPoint.x) * self.progress,
            y: self.fromPoint.y + (self.toPoint.y - self.fromPoint.y) * self.progress)
    }

    private var travelAngle: Angle {
        let dx = self.toPoint.x - self.fromPoint.x
        let dy = self.toPoint.y - self.fromPoint.y
        return Angle(radians: atan2(dy, dx))
    }

    private func animateSwipe() {
        let travel = max(self.duration * 0.7, 0.15)

        // Touch-down
        withAnimation(VisualizerMotion.pop(0.25)) {
            self.pressScale = 1.0
            self.pressOpacity = 0.9
        }
        withAnimation(VisualizerMotion.exit(0.3).delay(travel * 0.5)) {
            self.pressOpacity = 0
        }

        // Drag travel
        withAnimation(VisualizerMotion.glide(travel).delay(0.08)) {
            self.progress = 1.0
        }

        // Touch-up
        withAnimation(VisualizerMotion.pop(0.3).delay(travel)) {
            self.releaseScale = 1.0
            self.releaseOpacity = 0.9
            self.chevronOpacity = 1
        }

        // Dissolve
        withAnimation(VisualizerMotion.exit(0.3).delay(travel + 0.25)) {
            self.pathOpacity = 0
            self.releaseOpacity = 0
            self.chevronOpacity = 0
        }
    }
}

#if DEBUG && !SWIFT_PACKAGE
#Preview {
    VStack {
        SwipePathView(
            from: CGPoint(x: 50, y: 200),
            to: CGPoint(x: 350, y: 120),
            duration: 0.9)
            .frame(width: 400, height: 300)
            .background(Color.gray.opacity(0.3))
    }
}
#endif
