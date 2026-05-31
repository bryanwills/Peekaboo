import Foundation
import Testing
@testable import PeekabooCLI
@testable import PeekabooCore

@Suite(.tags(.safe), .serialized)
struct PasteCommandTests {
    @Test
    @MainActor
    func `Paste with app target defaults to background process delivery`() async throws {
        let app = ServiceApplicationInfo(
            processIdentifier: 2468,
            bundleIdentifier: "com.apple.TextEdit",
            name: "TextEdit"
        )
        let automation = StubAutomationService()
        let clipboard = StubClipboardService()
        let applications = StubApplicationService(applications: [app])
        let services = TestServicesFactory.makePeekabooServices(
            applications: applications,
            clipboard: clipboard,
            automation: automation
        )

        let result = try await InProcessCommandRunner.run(
            [
                "paste",
                "--app", "TextEdit",
                "--text", "smoke",
                "--restore-delay-ms", "0",
                "--json",
                "--no-remote",
            ],
            services: services
        )

        #expect(result.exitStatus == 0)
        #expect(automation.targetedHotkeyCalls.map(\.keys) == ["cmd,v"])
        #expect(automation.targetedHotkeyCalls.first?.targetProcessIdentifier == 2468)
        #expect(automation.hotkeyCalls.isEmpty)
        #expect(applications.activateCalls.isEmpty)
        let payload = try ExternalCommandRunner.decodeJSONResponse(
            from: result,
            as: CodableJSONResponse<PasteResult>.self
        )
        #expect(payload.data.deliveryMode == "background")
        #expect(payload.data.targetPID == 2468)
    }

    @Test
    @MainActor
    func `Paste foreground flag opts out of background process delivery`() async throws {
        let app = ServiceApplicationInfo(
            processIdentifier: 2468,
            bundleIdentifier: "com.apple.TextEdit",
            name: "TextEdit"
        )
        let automation = StubAutomationService()
        let clipboard = StubClipboardService()
        let services = TestServicesFactory.makePeekabooServices(
            applications: StubApplicationService(applications: [app]),
            clipboard: clipboard,
            automation: automation
        )

        let result = try await InProcessCommandRunner.run(
            [
                "paste",
                "--app", "TextEdit",
                "--text", "smoke",
                "--foreground",
                "--restore-delay-ms", "0",
                "--json",
                "--no-remote",
            ],
            services: services
        )

        #expect(result.exitStatus == 0)
        #expect(automation.targetedHotkeyCalls.isEmpty)
        #expect(automation.hotkeyCalls.map(\.keys) == ["cmd,v"])
        let payload = try ExternalCommandRunner.decodeJSONResponse(
            from: result,
            as: CodableJSONResponse<PasteResult>.self
        )
        #expect(payload.data.deliveryMode == "foreground")
        #expect(payload.data.targetPID == nil)
    }

    @Test
    @MainActor
    func `Paste fails before mutating clipboard when explicit app target is missing`() async throws {
        let automation = StubAutomationService()
        let clipboard = StubClipboardService()
        let services = TestServicesFactory.makePeekabooServices(
            applications: StubApplicationService(applications: []),
            clipboard: clipboard,
            automation: automation
        )

        let result = try await InProcessCommandRunner.run(
            [
                "paste",
                "--app", "NoSuchPeekabooApp",
                "--text", "smoke",
                "--json",
                "--no-remote",
            ],
            services: services
        )

        #expect(result.exitStatus == 1)
        #expect(result.stdout.contains("\"success\" : false"))
        #expect(result.stdout.contains("\"code\" : \"APP_NOT_FOUND\""))
        #expect(automation.hotkeyCalls.isEmpty)
        #expect(try clipboard.get(prefer: nil) == nil)
    }
}
