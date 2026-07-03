import CoreGraphics
import PeekabooFoundation
import Testing
@testable import PeekabooVisualizer

@MainActor
struct VisualizerOverlaySizingTests {
    @Test
    func `Typing feedback masks printable keys unless revealed`() {
        let keys = ["H", "i", " ", "{return}", "{tab}", "4"]

        let masked = VisualizationClient.maskedTypingKeys(keys, reveal: false)
        #expect(masked == ["•", "•", "•", "{return}", "{tab}", "•"])

        let revealed = VisualizationClient.maskedTypingKeys(keys, reveal: true)
        #expect(revealed == keys)
    }

    @Test
    func `Typing stream always finishes within the overlay window`() {
        // Callers pass fixed display durations (e.g. 2.0s scaled to 6s), so a
        // long string at human cadence must compress instead of truncating.
        let longText = 80
        let interval = TypeAnimationView.keyInterval(
            cadence: .human(wordsPerMinute: 140),
            durationScale: 3.0,
            keyCount: longText,
            displayDuration: 6.0)

        #expect(Double(longText) * interval <= 6.0)
    }

    @Test
    func `Typing stream keeps cadence pace when it fits`() {
        // 5 keys at 140 WPM (~0.086s/key) scaled 3x should keep the slow-mo
        // cadence pace rather than compressing.
        let interval = TypeAnimationView.keyInterval(
            cadence: .human(wordsPerMinute: 140),
            durationScale: 3.0,
            keyCount: 5,
            displayDuration: 6.0)

        #expect(abs(interval - (60.0 / 700.0) * 3.0) < 0.001)
    }

    @Test
    func `Travel window rect covers both endpoints with padding`() {
        let from = CGPoint(x: 500, y: 900)
        let to = CGPoint(x: 200, y: 300)
        let rect = VisualizerCoordinator.travelWindowRect(from: from, to: to, padding: 50)

        #expect(rect == CGRect(x: 150, y: 250, width: 400, height: 700))
    }

    @Test
    func `Window-local points flip AppKit coordinates`() {
        let windowRect = CGRect(x: 100, y: 200, width: 400, height: 300)

        // Bottom-left corner of the window in screen space is the
        // bottom-left in SwiftUI space too, but y measures from the top.
        let bottomLeft = VisualizerCoordinator.windowLocalPoint(CGPoint(x: 100, y: 200), in: windowRect)
        #expect(bottomLeft == CGPoint(x: 0, y: 300))

        let topRight = VisualizerCoordinator.windowLocalPoint(CGPoint(x: 500, y: 500), in: windowRect)
        #expect(topRight == CGPoint(x: 400, y: 0))
    }

    @Test
    func `Hotkey overlay grows with more keys`() {
        let compact = VisualizerCoordinator.estimatedHotkeyOverlaySize(for: ["cmd", "k"])
        let wide = VisualizerCoordinator.estimatedHotkeyOverlaySize(for: ["cmd", "shift", "option", "ctrl", "space"])

        #expect(compact.width >= 400)
        #expect(compact.height >= 160)
        #expect(wide.width > compact.width)
        #expect(wide.height >= compact.height)
    }

    @Test
    func `Menu overlay grows with path length`() {
        let short = VisualizerCoordinator.estimatedMenuOverlaySize(for: ["File", "New"])
        let long = VisualizerCoordinator.estimatedMenuOverlaySize(for: ["File", "New", "Project", "Swift Package"])

        #expect(short.width >= 600)
        #expect(long.width > short.width)
        #expect(short.height > 0)
        #expect(long.height == short.height)
    }
}
