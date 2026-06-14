import CoreGraphics
import enum PeekabooFoundation.PeekabooError
import Testing
@testable import PeekabooAutomationKit

struct ClickServiceExactWindowTests {
    @Test
    @MainActor
    func `Background coordinate click preserves exact target window`() async throws {
        let synthetic = ClickRecordingSyntheticInputDriver()
        let service = ClickService(
            snapshotManager: InMemorySnapshotManager(),
            inputPolicy: UIInputPolicy(defaultStrategy: .synthOnly),
            syntheticInputDriver: synthetic)

        _ = try await service.click(
            target: .coordinates(CGPoint(x: 10, y: 20)),
            clickType: .single,
            snapshotId: nil,
            targetProcessIdentifier: 12345,
            targetWindowID: 42)

        #expect(synthetic.events == [
            .targetedClick(
                point: CGPoint(x: 10, y: 20),
                button: .left,
                count: 1,
                targetProcessIdentifier: 12345,
                targetWindowID: 42),
        ])
    }

    @Test
    @MainActor
    func `Exact window identifier must fit CGWindowID`() async {
        let synthetic = ClickRecordingSyntheticInputDriver()
        let service = ClickService(
            snapshotManager: InMemorySnapshotManager(),
            inputPolicy: UIInputPolicy(defaultStrategy: .synthOnly),
            syntheticInputDriver: synthetic)

        await #expect(throws: PeekabooError.self) {
            try await service.click(
                target: .coordinates(CGPoint(x: 10, y: 20)),
                clickType: .single,
                snapshotId: nil,
                targetProcessIdentifier: getpid(),
                targetWindowID: Int(UInt32.max) + 1)
        }
        #expect(synthetic.events.isEmpty)
    }

    @Test
    @MainActor
    func `Snapshotless exact query is rejected before delivery`() async {
        let synthetic = ClickRecordingSyntheticInputDriver()
        let service = ClickService(
            snapshotManager: InMemorySnapshotManager(),
            inputPolicy: UIInputPolicy(defaultStrategy: .synthOnly),
            syntheticInputDriver: synthetic)

        await #expect(throws: PeekabooError.self) {
            try await service.click(
                target: .query("Save"),
                clickType: .single,
                snapshotId: nil,
                targetProcessIdentifier: getpid(),
                targetWindowID: 42)
        }
        #expect(synthetic.events.isEmpty)
    }

    @Test
    @MainActor
    func `Missing targeted snapshot reports stale snapshot`() async {
        let synthetic = ClickRecordingSyntheticInputDriver()
        let service = UIAutomationService(
            snapshotManager: InMemorySnapshotManager(),
            inputPolicy: UIInputPolicy(defaultStrategy: .synthOnly),
            actionInputDriver: ActionInputDriver(),
            syntheticInputDriver: synthetic,
            automationElementResolver: AutomationElementResolver())

        do {
            _ = try await service.click(
                target: .elementId("B1"),
                clickType: .single,
                snapshotId: "expired-snapshot",
                targetProcessIdentifier: getpid(),
                targetWindowID: 42)
            Issue.record("Expected stale snapshot error")
        } catch let PeekabooError.snapshotStale(reason) {
            #expect(reason.contains("no longer available"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(synthetic.events.isEmpty)
    }

    @Test
    @MainActor
    func `Application menu target cannot use a document window`() async {
        let pid = getpid()
        let menuItem = DetectedElement(
            id: "M1",
            type: .menuItem,
            label: "Save",
            bounds: CGRect(x: 10, y: 10, width: 40, height: 20),
            attributes: [
                "role": "AXMenuItem",
                DetectedElementRootPolicy.sourceAttribute: DetectedElementRootPolicy.applicationMenuBarSource,
            ])
        let detectionResult = ElementDetectionResult(
            snapshotId: "snapshot",
            screenshotPath: "/tmp/shot.png",
            elements: DetectedElements(menus: [menuItem]),
            metadata: DetectionMetadata(
                detectionTime: 0.01,
                elementCount: 1,
                method: "test",
                windowContext: WindowContext(applicationProcessId: pid, windowID: 42)))
        let synthetic = ClickRecordingSyntheticInputDriver()
        let service = ClickService(
            snapshotManager: InMemorySnapshotManager(detectionResult: detectionResult),
            inputPolicy: UIInputPolicy(defaultStrategy: .synthOnly),
            syntheticInputDriver: synthetic)

        await #expect(throws: PeekabooError.self) {
            try await service.click(
                target: .elementId("M1"),
                clickType: .single,
                snapshotId: "snapshot",
                targetProcessIdentifier: pid,
                targetWindowID: 42)
        }
        #expect(synthetic.events.isEmpty)
    }

    @Test
    @MainActor
    func `Window-owned context menu targets remain pinnable`() async throws {
        let pid = getpid()
        let tracker = ExactWindowTracker()
        let previousTracker = WindowMovementTracking.provider
        WindowMovementTracking.provider = tracker
        defer { WindowMovementTracking.provider = previousTracker }
        let targets = [
            DetectedElement(
                id: "context-menu",
                type: .menu,
                label: "Context Menu",
                bounds: CGRect(x: 10, y: 10, width: 40, height: 20),
                attributes: ["role": "AXMenu"]),
            DetectedElement(
                id: "context-menu-item",
                type: .menuItem,
                label: "Open",
                bounds: CGRect(x: 20, y: 30, width: 60, height: 20),
                attributes: ["role": "AXMenuItem"]),
        ]

        for target in targets {
            let detectionResult = ElementDetectionResult(
                snapshotId: "snapshot",
                screenshotPath: "/tmp/shot.png",
                elements: DetectedElements(menus: [target]),
                metadata: DetectionMetadata(
                    detectionTime: 0.01,
                    elementCount: 1,
                    method: "test",
                    windowContext: WindowContext(applicationProcessId: pid, windowID: 42)))
            let synthetic = ClickRecordingSyntheticInputDriver()
            let service = ClickService(
                snapshotManager: InMemorySnapshotManager(detectionResult: detectionResult),
                inputPolicy: UIInputPolicy(defaultStrategy: .synthOnly),
                syntheticInputDriver: synthetic)

            let result = try await service.click(
                target: .elementId(target.id),
                clickType: .single,
                snapshotId: "snapshot",
                targetProcessIdentifier: pid,
                targetWindowID: 42)

            #expect(result.path == .synth)
            #expect(synthetic.events == [
                .targetedClick(
                    point: CGPoint(x: target.bounds.midX, y: target.bounds.midY),
                    button: .left,
                    count: 1,
                    targetProcessIdentifier: pid,
                    targetWindowID: 42),
            ])
        }
    }

    @Test
    func `Legacy disk-backed menu bar IDs retain application-root scope`() {
        let menuItem = DetectedElement(
            id: "menuitem_7",
            type: .other,
            label: "Save",
            bounds: .zero)

        #expect(DetectedElementRootPolicy.requiresApplicationRoot(menuItem))
    }
}

private final class ExactWindowTracker: WindowTrackingProviding, @unchecked Sendable {
    @MainActor
    func windowBounds(for _: CGWindowID) -> CGRect? {
        .zero
    }
}
