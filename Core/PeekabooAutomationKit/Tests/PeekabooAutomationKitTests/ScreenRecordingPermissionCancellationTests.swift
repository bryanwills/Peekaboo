import Foundation
import Testing
@testable import PeekabooAutomationKit

@MainActor
struct ScreenRecordingPermissionCancellationTests {
    @Test
    func `cancel during transient permission retry skips second probe`() async {
        let logger = MockLoggingService().logger(category: "test")
        var probeCount = 0
        let checker = ScreenRecordingPermissionChecker(
            preflight: { false },
            shareableContentProbe: {
                probeCount += 1
                throw Self.transientDenial
            })

        let task = Task { @MainActor in
            await checker.hasPermission(logger: logger)
        }

        while probeCount == 0 {
            await Task.yield()
        }
        task.cancel()

        #expect(await task.value == false)
        #expect(probeCount == 1)
    }

    @Test
    func `noncancelled transient permission retry probes twice`() async {
        let logger = MockLoggingService().logger(category: "test")
        var probeCount = 0
        let checker = ScreenRecordingPermissionChecker(
            preflight: { false },
            shareableContentProbe: {
                probeCount += 1
                throw Self.transientDenial
            })

        #expect(await checker.hasPermission(logger: logger) == false)
        #expect(probeCount == 2)
    }

    private static let transientDenial = NSError(
        domain: "com.apple.ScreenCaptureKit.SCStreamErrorDomain",
        code: -3801,
        userInfo: [
            NSLocalizedDescriptionKey: "The user declined TCCs for application, window, display capture",
        ])
}
