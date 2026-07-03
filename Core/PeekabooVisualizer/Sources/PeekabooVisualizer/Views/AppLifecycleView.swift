//
//  AppLifecycleView.swift
//  Peekaboo
//
//  A HUD toast announcing app launch/quit with the app's icon.
//

import SwiftUI

/// App lifecycle feedback: a toast with the app icon and a status line.
/// Launch springs the icon in with a glow sweep; quit desaturates and sinks it.
struct AppLifecycleView: View {
    let appName: String
    let iconPath: String?
    let action: LifecycleAction
    let duration: TimeInterval

    @State private var chipScale: CGFloat = 0.92
    @State private var chipOpacity: Double = 0
    @State private var chipOffset: CGFloat = 0
    @State private var iconScale: CGFloat = 0.6
    @State private var iconSaturation: Double = 1
    @State private var sweepScale: CGFloat = 0.6
    @State private var sweepOpacity: Double = 0

    enum LifecycleAction {
        case launch
        case quit

        var statusTint: Color {
            switch self {
            case .launch: VisualizerTheme.positive
            case .quit: VisualizerTheme.destructive
            }
        }

        var text: String {
            switch self {
            case .launch: "Launching"
            case .quit: "Quitting"
            }
        }
    }

    init(appName: String, iconPath: String?, action: LifecycleAction, duration: TimeInterval = 2.0) {
        self.appName = appName
        self.iconPath = iconPath
        self.action = action
        self.duration = duration
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                // One-shot glow sweep behind the icon on launch
                if self.action == .launch {
                    Circle()
                        .stroke(VisualizerTheme.accent.opacity(0.8), lineWidth: 2)
                        .frame(width: 56, height: 56)
                        .scaleEffect(self.sweepScale)
                        .opacity(self.sweepOpacity)
                }

                self.iconView
                    .frame(width: 48, height: 48)
                    .scaleEffect(self.iconScale)
                    .saturation(self.iconSaturation)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(self.appName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(VisualizerTheme.hudText)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Circle()
                        .fill(self.action.statusTint)
                        .frame(width: 6, height: 6)
                    Text(self.action.text)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(VisualizerTheme.hudTextSecondary)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .hudChip(cornerRadius: 18)
        .scaleEffect(self.chipScale)
        .offset(y: self.chipOffset)
        .opacity(self.chipOpacity)
        .onAppear {
            self.animateLifecycle()
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconPath, let image = NSImage(contentsOfFile: iconPath) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(VisualizerTheme.hudTextSecondary)
        }
    }

    private func animateLifecycle() {
        withAnimation(VisualizerMotion.pop()) {
            self.chipScale = 1.0
            self.chipOpacity = 1
        }

        switch self.action {
        case .launch:
            withAnimation(VisualizerMotion.pop(0.4).delay(0.1)) {
                self.iconScale = 1.0
            }
            // Glow ring sweeps outward once
            self.sweepOpacity = 1
            withAnimation(VisualizerMotion.enter(0.6).delay(0.2)) {
                self.sweepScale = 1.7
            }
            withAnimation(VisualizerMotion.exit(0.35).delay(0.4)) {
                self.sweepOpacity = 0
            }

        case .quit:
            self.iconScale = 1.0
            withAnimation(VisualizerMotion.glide(self.duration * 0.5).delay(0.25)) {
                self.iconSaturation = 0
                self.iconScale = 0.9
            }
        }

        // Toast slips away
        withAnimation(VisualizerMotion.exit(0.35).delay(max(self.duration - 0.4, 0.5))) {
            self.chipOpacity = 0
            self.chipOffset = self.action == .quit ? 10 : -10
        }
    }
}

#if DEBUG && !SWIFT_PACKAGE
#Preview {
    VStack(spacing: 40) {
        AppLifecycleView(
            appName: "Safari",
            iconPath: nil,
            action: .launch,
            duration: 3.0)

        AppLifecycleView(
            appName: "TextEdit",
            iconPath: nil,
            action: .quit,
            duration: 3.0)
    }
    .frame(width: 400, height: 300)
    .background(Color.gray.opacity(0.3))
}
#endif
