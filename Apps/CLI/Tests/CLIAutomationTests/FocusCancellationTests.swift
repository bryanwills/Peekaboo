import PeekabooCore
import Testing
@testable import PeekabooCLI

@Suite(.tags(.safe))
@MainActor
struct FocusCancellationTests {
    @Test
    func `Cancellation during fallback activation propagates after the service returns`() async {
        let bundleIdentifier = "com.example.focus-cancellation"
        let application = ServiceApplicationInfo(
            processIdentifier: 4242,
            bundleIdentifier: bundleIdentifier,
            name: "Focus Cancellation"
        )
        let applications = StubApplicationService(applications: [application])
        applications.activateApplicationHandler = { _ in
            withUnsafeCurrentTask { $0?.cancel() }
        }
        let services = TestServicesFactory.makePeekabooServices(applications: applications)
        let options = FocusOptions(
            autoFocus: true,
            focusTimeout: nil,
            focusRetryCount: nil,
            spaceSwitch: false,
            bringToCurrentSpace: false
        )
        let task = Task { @MainActor in
            try await ensureFocused(
                applicationName: bundleIdentifier,
                options: options,
                services: services
            )
        }

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(applications.activateCalls == [bundleIdentifier])
    }
}
