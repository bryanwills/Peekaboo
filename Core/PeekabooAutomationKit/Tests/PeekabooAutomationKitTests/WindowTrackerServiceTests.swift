import CoreGraphics
import Testing
@testable import PeekabooAutomationKit

struct WindowTrackerServiceTests {
    @Test
    @MainActor
    func `Movement tracking refreshes exact window on cache miss and preserves cache hits`() {
        let windowID = CGWindowID(42)
        let bounds = CGRect(x: 40, y: 50, width: 300, height: 200)
        let source = WindowInfoSource(currentInfo: Self.windowInfo(
            windowID: windowID,
            bounds: bounds,
            ownerPID: 111))
        let tracker = WindowTrackerService(
            configuration: WindowTrackerConfiguration(useAXNotifications: false),
            windowInfoProvider: { source.info(for: $0) })
        let previousTracker = WindowMovementTracking.provider
        WindowMovementTracking.provider = tracker
        defer { WindowMovementTracking.provider = previousTracker }
        let snapshot = UIAutomationSnapshot(
            applicationProcessId: 111,
            windowBounds: bounds,
            windowID: windowID)

        let firstResult = WindowMovementTracking.adjustPoint(CGPoint(x: 80, y: 90), snapshot: snapshot)
        source.currentInfo = nil
        let secondResult = WindowMovementTracking.adjustPoint(CGPoint(x: 80, y: 90), snapshot: snapshot)

        guard case .unchanged = firstResult else {
            Issue.record("Expected exact-window refresh to recover the cache miss, got \(firstResult)")
            return
        }
        guard case .unchanged = secondResult else {
            Issue.record("Expected cached exact-window hit, got \(secondResult)")
            return
        }
        #expect(source.requestedWindowIDs == [windowID])
    }

    @Test
    @MainActor
    func `Refresh replaces cached identity and removes missing windows`() {
        let windowID = CGWindowID(42)
        let source = WindowInfoSource(currentInfo: Self.windowInfo(
            windowID: windowID,
            bounds: CGRect(x: 10, y: 20, width: 300, height: 200),
            ownerPID: 111))
        let tracker = WindowTrackerService(
            configuration: WindowTrackerConfiguration(useAXNotifications: false),
            windowInfoProvider: { _ in source.currentInfo })

        tracker.refreshWindow(windowID: windowID)
        #expect(tracker.windowBounds(for: windowID) == CGRect(x: 10, y: 20, width: 300, height: 200))
        #expect(tracker.windowOwnerProcessIdentifier(for: windowID) == 111)

        source.currentInfo = Self.windowInfo(
            windowID: windowID,
            bounds: CGRect(x: 40, y: 50, width: 500, height: 400),
            ownerPID: 222)
        tracker.refreshWindow(windowID: windowID)
        #expect(tracker.windowBounds(for: windowID) == CGRect(x: 40, y: 50, width: 500, height: 400))
        #expect(tracker.windowOwnerProcessIdentifier(for: windowID) == 222)

        source.currentInfo = nil
        tracker.refreshWindow(windowID: windowID)
        #expect(tracker.windowBounds(for: windowID) == nil)
        #expect(tracker.windowOwnerProcessIdentifier(for: windowID) == nil)
    }

    private static func windowInfo(
        windowID: CGWindowID,
        bounds: CGRect,
        ownerPID: pid_t) -> WindowIdentityInfo
    {
        WindowIdentityInfo(
            windowID: windowID,
            title: nil,
            bounds: bounds,
            ownerPID: ownerPID,
            applicationName: nil,
            bundleIdentifier: nil,
            layer: 0,
            alpha: 1,
            axIdentifier: nil)
    }
}

@MainActor
private final class WindowInfoSource {
    var currentInfo: WindowIdentityInfo?
    private(set) var requestedWindowIDs: [CGWindowID] = []

    init(currentInfo: WindowIdentityInfo?) {
        self.currentInfo = currentInfo
    }

    func info(for windowID: CGWindowID) -> WindowIdentityInfo? {
        self.requestedWindowIDs.append(windowID)
        return self.currentInfo
    }
}
