import CoreGraphics
import PeekabooCore
import Testing
@testable import PeekabooCLI

struct FocusTargetResolverTests {
    @Test
    @MainActor
    func `Optional focus lookups propagate cancellation`() async {
        let task = Task { @MainActor in
            try await FocusFailurePolicy.optional {
                withUnsafeCurrentTask { $0?.cancel() }
                return 42
            }
        }

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        await #expect(throws: CancellationError.self) {
            try await FocusFailurePolicy.flatteningOptional { () async throws -> Int? in
                throw CancellationError()
            }
        }
    }

    @Test
    func `explicit windowID always wins`() {
        let snapshot = UIAutomationSnapshot(
            applicationBundleId: "com.example.app",
            windowTitle: "X",
            windowID: 42
        )
        let result = FocusTargetResolver.resolve(
            windowID: 777,
            snapshot: snapshot,
            applicationName: "Safari",
            windowTitle: "GitHub"
        )

        #expect(result == .windowId(777))
    }

    @Test
    func `snapshot windowID wins when present`() {
        let snapshot = UIAutomationSnapshot(
            applicationBundleId: "com.example.app",
            windowTitle: "X",
            windowID: 42
        )
        let result = FocusTargetResolver.resolve(
            windowID: nil,
            snapshot: snapshot,
            applicationName: "Safari",
            windowTitle: "GitHub"
        )

        #expect(result == .windowId(42))
    }

    @Test
    func `snapshot without windowID falls back to bundleId + title`() {
        let snapshot = UIAutomationSnapshot(
            applicationBundleId: "com.example.app",
            windowTitle: "My Window",
            windowID: nil
        )
        let result = FocusTargetResolver.resolve(
            windowID: nil,
            snapshot: snapshot,
            applicationName: nil,
            windowTitle: nil
        )

        #expect(result == .bestWindow(applicationName: "com.example.app", windowTitle: "My Window"))
    }

    @Test
    func `explicit app/title override snapshot metadata when windowID missing`() {
        let snapshot = UIAutomationSnapshot(
            applicationBundleId: "com.example.app",
            windowTitle: "Old Title",
            windowID: nil
        )
        let result = FocusTargetResolver.resolve(
            windowID: nil,
            snapshot: snapshot,
            applicationName: "Safari",
            windowTitle: "GitHub"
        )

        #expect(result == .bestWindow(applicationName: "Safari", windowTitle: "GitHub"))
    }

    @Test
    func `no snapshot, app resolves to best window`() {
        let result = FocusTargetResolver.resolve(
            windowID: nil,
            snapshot: nil,
            applicationName: "Safari",
            windowTitle: nil
        )

        #expect(result == .bestWindow(applicationName: "Safari", windowTitle: nil))
    }

    @Test
    func `no inputs returns nil`() {
        let result = FocusTargetResolver.resolve(
            windowID: nil,
            snapshot: nil,
            applicationName: nil,
            windowTitle: nil
        )

        #expect(result == nil)
    }
}
