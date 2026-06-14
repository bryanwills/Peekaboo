import CoreGraphics
import Foundation
import enum PeekabooFoundation.PeekabooError
import Testing
@testable import PeekabooAutomationKit

struct TypeServiceTargetResolutionTests {
    @Test
    @MainActor
    func `action-first missing snapshot fails as stale instead of falling back`() async {
        let service = TypeService(
            snapshotManager: InMemorySnapshotManager(),
            inputPolicy: UIInputPolicy(defaultStrategy: .actionFirst))

        do {
            try await service.type(
                text: "hello",
                target: "T1",
                clearExisting: true,
                typingDelay: 0,
                snapshotId: "missing")
            Issue.record("Expected stale element error for missing action snapshot.")
        } catch let error as ActionInputError {
            #expect(error == .staleElement)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    @MainActor
    func `synthetic type treats explicit missing snapshot as authoritative`() async {
        let service = TypeService(
            snapshotManager: InMemorySnapshotManager(),
            inputPolicy: UIInputPolicy(defaultStrategy: .synthOnly))

        do {
            try await service.type(
                text: "hello",
                target: "missing-\(UUID().uuidString)",
                clearExisting: false,
                typingDelay: 0,
                snapshotId: "missing")
            Issue.record("Expected stale element error for missing synthetic snapshot.")
        } catch let error as ActionInputError {
            #expect(error == .staleElement)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    @MainActor
    func `action-first type does not escape an explicit snapshot`() async throws {
        let snapshotId = "snapshot"
        let detectionResult = ElementDetectionResult(
            snapshotId: snapshotId,
            screenshotPath: "/tmp/shot.png",
            elements: DetectedElements(),
            metadata: DetectionMetadata(detectionTime: 0.01, elementCount: 0, method: "test"))
        let resolver = RecordingTypeAutomationElementResolver()
        let service = TypeService(
            snapshotManager: InMemorySnapshotManager(detectionResult: detectionResult),
            inputPolicy: UIInputPolicy(defaultStrategy: .actionFirst),
            automationElementResolver: resolver)

        do {
            try await service.type(
                text: "hello",
                target: "outside-snapshot",
                clearExisting: true,
                typingDelay: 0,
                snapshotId: snapshotId)
            Issue.record("Expected missing snapshot target error.")
        } catch let PeekabooError.elementNotFound(identifier) {
            #expect(identifier == "outside-snapshot")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(resolver.queryResolutionCount == 0)
    }

    @Test
    func `special key mapping preserves raw SpecialKey semantics`() {
        #expect(TypeServiceSpecialKeyMapping.keyCode(for: .return) == 0x24)
        #expect(TypeServiceSpecialKeyMapping.keyCode(for: .enter) == 0x4C)
        #expect(TypeServiceSpecialKeyMapping.keyCode(for: .forwardDelete) == 0x75)
        #expect(TypeServiceSpecialKeyMapping.keyCode(for: .capsLock) == 0x39)
        #expect(TypeServiceSpecialKeyMapping.keyCode(for: .clear) == 0x47)
        #expect(TypeServiceSpecialKeyMapping.keyCode(for: .help) == 0x72)
    }

    @Test
    func `special key mapping accepts CLI aliases`() {
        #expect(TypeServiceSpecialKeyMapping.keyCode(forRawKey: "esc") == 0x35)
        #expect(TypeServiceSpecialKeyMapping.keyCode(forRawKey: "spacebar") == 0x31)
        #expect(TypeServiceSpecialKeyMapping.keyCode(forRawKey: "forward_delete") == 0x75)
        #expect(TypeServiceSpecialKeyMapping.keyCode(forRawKey: "caps_lock") == 0x39)
        #expect(TypeServiceSpecialKeyMapping.keyCode(forRawKey: "page_up") == 0x74)
        #expect(TypeServiceSpecialKeyMapping.keyCode(forRawKey: "arrow_down") == 0x7D)
    }

    @Test
    @MainActor
    func `resolveTargetElement matches identifier over other fields`() {
        let basic = DetectedElement(
            id: "T1",
            type: .textField,
            label: "Type here...",
            value: nil,
            bounds: .init(x: 0, y: 0, width: 100, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "basic-text-field"])
        let number = DetectedElement(
            id: "T2",
            type: .textField,
            label: "Numbers only...",
            value: nil,
            bounds: .init(x: 0, y: 24, width: 100, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "number-text-field"])

        let detectionResult = ElementDetectionResult(
            snapshotId: "snapshot",
            screenshotPath: "/tmp/shot.png",
            elements: DetectedElements(textFields: [basic, number]),
            metadata: DetectionMetadata(detectionTime: 0.01, elementCount: 2, method: "test"))

        #expect(TypeService.resolveTargetElement(query: "basic-text-field", in: detectionResult)?.id == "T1")
        #expect(TypeService.resolveTargetElement(query: "number-text-field", in: detectionResult)?.id == "T2")
        #expect(TypeService.resolveTargetElement(query: "Type here...", in: detectionResult)?.id == "T1")
        #expect(TypeService.resolveTargetElement(query: "Numbers only...", in: detectionResult)?.id == "T2")
    }

    @Test
    @MainActor
    func `resolveTargetElement returns nil for unknown query`() {
        let element = DetectedElement(
            id: "T1",
            type: .textField,
            label: "Type here...",
            value: nil,
            bounds: .init(x: 0, y: 0, width: 100, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "basic-text-field"])

        let detectionResult = ElementDetectionResult(
            snapshotId: "snapshot",
            screenshotPath: "/tmp/shot.png",
            elements: DetectedElements(textFields: [element]),
            metadata: DetectionMetadata(detectionTime: 0.01, elementCount: 1, method: "test"))

        #expect(TypeService.resolveTargetElement(query: "does-not-exist", in: detectionResult) == nil)
    }

    @Test
    @MainActor
    func `resolveTargetElement breaks ties deterministically`() {
        let higher = DetectedElement(
            id: "T_HIGH",
            type: .textField,
            label: "Type here...",
            value: nil,
            bounds: .init(x: 0, y: 100, width: 100, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "basic-text-field"])
        let lower = DetectedElement(
            id: "T_LOW",
            type: .textField,
            label: "Type here...",
            value: nil,
            bounds: .init(x: 0, y: 40, width: 100, height: 20),
            isEnabled: true,
            isSelected: nil,
            attributes: ["identifier": "basic-text-field"])

        let detectionResult = ElementDetectionResult(
            snapshotId: "snapshot",
            screenshotPath: "/tmp/shot.png",
            elements: DetectedElements(textFields: [higher, lower]),
            metadata: DetectionMetadata(detectionTime: 0.01, elementCount: 2, method: "test"))

        #expect(TypeService.resolveTargetElement(query: "basic-text-field", in: detectionResult)?.id == "T_LOW")
    }
}

@MainActor
private final class RecordingTypeAutomationElementResolver: AutomationElementResolving {
    private(set) var queryResolutionCount = 0

    func resolve(detectedElement _: DetectedElement, windowContext _: WindowContext?) -> AutomationElement? {
        nil
    }

    func resolve(query _: String, windowContext _: WindowContext?, requireTextInput _: Bool) -> AutomationElement? {
        self.queryResolutionCount += 1
        return nil
    }
}
