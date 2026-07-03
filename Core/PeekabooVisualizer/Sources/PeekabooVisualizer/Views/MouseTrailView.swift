//
//  MouseTrailView.swift
//  Peekaboo
//
//  A comet with a tapered glowing trail tracing the cursor's travel.
//

import SwiftUI

/// Mouse-movement feedback: a glowing head glides from start to destination,
/// stretching a soft gradient tail behind it, and lands with a small ring.
/// Points are window-local SwiftUI coordinates (top-left origin).
struct MouseTrailView: View {
    let fromPoint: CGPoint
    let toPoint: CGPoint
    let duration: TimeInterval

    @State private var progress: CGFloat = 0
    @State private var trailOpacity: Double = 1
    @State private var headOpacity: Double = 0
    @State private var landingScale: CGFloat = 0.3
    @State private var landingOpacity: Double = 0

    init(from: CGPoint, to: CGPoint, duration: TimeInterval = 1.0) {
        self.fromPoint = from
        self.toPoint = to
        self.duration = duration
    }

    var body: some View {
        ZStack {
            // Soft afterglow beneath the trail
            self.trailPath
                .trim(from: max(0, self.progress - 0.35), to: self.progress)
                .stroke(
                    VisualizerTheme.accent.opacity(0.35),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .blur(radius: 5)
                .opacity(self.trailOpacity)

            // Tapered comet tail
            self.trailPath
                .trim(from: max(0, self.progress - 0.35), to: self.progress)
                .stroke(
                    self.travelGradient,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .opacity(self.trailOpacity)

            // Comet head
            Circle()
                .fill(.white)
                .frame(width: 7, height: 7)
                .background(
                    Circle()
                        .fill(VisualizerTheme.accent)
                        .frame(width: 15, height: 15)
                        .blur(radius: 3))
                .position(self.headPosition)
                .opacity(self.headOpacity)
                .shadow(color: VisualizerTheme.accent.opacity(0.9), radius: 7)

            // Landing ring at the destination
            Circle()
                .stroke(VisualizerTheme.accent, lineWidth: 2)
                .frame(width: 34, height: 34)
                .scaleEffect(self.landingScale)
                .opacity(self.landingOpacity)
                .position(self.toPoint)
        }
        .onAppear {
            self.animateTrail()
        }
    }

    private var trailPath: Path {
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

    /// Gradient oriented along the travel direction so the tail fades out behind the head.
    private var travelGradient: LinearGradient {
        LinearGradient(
            colors: [VisualizerTheme.accent.opacity(0.05), VisualizerTheme.accentSecondary, .white],
            startPoint: self.unitPoint(for: self.fromPoint),
            endPoint: self.unitPoint(for: self.toPoint))
    }

    private func unitPoint(for point: CGPoint) -> UnitPoint {
        let bounds = self.trailPath.boundingRect.insetBy(dx: -1, dy: -1)
        return UnitPoint(
            x: (point.x - bounds.minX) / max(bounds.width, 1),
            y: (point.y - bounds.minY) / max(bounds.height, 1))
    }

    private func animateTrail() {
        let travel = max(self.duration * 0.75, 0.15)

        withAnimation(VisualizerMotion.enter(0.1)) {
            self.headOpacity = 1
        }
        withAnimation(VisualizerMotion.glide(travel)) {
            self.progress = 1.0
        }

        // Landing ring blooms as the head arrives
        withAnimation(VisualizerMotion.enter(0.25).delay(travel * 0.9)) {
            self.landingScale = 1.0
            self.landingOpacity = 0.9
        }
        withAnimation(VisualizerMotion.exit(0.2).delay(travel + 0.15)) {
            self.landingOpacity = 0
        }

        // Trail and head dissolve after arrival
        withAnimation(VisualizerMotion.exit(0.25).delay(travel)) {
            self.trailOpacity = 0
            self.headOpacity = 0
        }
    }
}

#if DEBUG && !SWIFT_PACKAGE
#Preview {
    MouseTrailView(
        from: CGPoint(x: 60, y: 80),
        to: CGPoint(x: 340, y: 320),
        duration: 1.2)
        .frame(width: 400, height: 400)
        .background(Color.gray.opacity(0.3))
}
#endif
