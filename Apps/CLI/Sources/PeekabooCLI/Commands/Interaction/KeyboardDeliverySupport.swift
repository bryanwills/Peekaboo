import Commander
import CoreGraphics
import Foundation
import PeekabooCore
import PeekabooFoundation

enum KeyboardDeliveryMode: String {
    case background
    case foreground
}

enum KeyboardDeliverySupport {
    static func backgroundProcessIdentifier(
        target: InteractionTargetOptions,
        snapshotId: String?,
        services: any PeekabooServiceProviding
    ) async throws -> pid_t? {
        try await self.validateWindowSelectionIfNeeded(target: target, services: services)

        if let windowId = target.windowId {
            return self.processIdentifierForWindow(windowId: CGWindowID(windowId))
        }

        if let pid = target.pid {
            guard pid > 0 else {
                throw ValidationError("--pid must be greater than 0")
            }
            return pid_t(pid)
        }

        if let appIdentifier = target.app?.trimmingCharacters(in: .whitespacesAndNewlines),
           !appIdentifier.isEmpty {
            let app = try await services.applications.findApplication(identifier: appIdentifier)
            return pid_t(app.processIdentifier)
        }

        if let snapshotId,
           let snapshot = try? await services.snapshots.getUIAutomationSnapshot(snapshotId: snapshotId),
           let processId = snapshot.applicationProcessId {
            return pid_t(processId)
        }

        if let snapshotId,
           let detectionResult = try? await services.snapshots.getDetectionResult(snapshotId: snapshotId),
           let processId = detectionResult.metadata.windowContext?.applicationProcessId {
            return pid_t(processId)
        }

        return nil
    }

    private static func validateWindowSelectionIfNeeded(
        target: InteractionTargetOptions,
        services: any PeekabooServiceProviding
    ) async throws {
        guard target.windowTitle != nil || target.windowIndex != nil || target.windowId != nil else {
            return
        }

        guard let windowTarget = try target.toWindowTarget() else {
            return
        }

        let windows = try await services.windows.listWindows(target: windowTarget)
        if windows.isEmpty {
            throw PeekabooError.windowNotFound(criteria: self.windowCriteriaDescription(target: target))
        }
    }

    static func validateForegroundFlags(
        foreground: Bool,
        focusOptions: FocusCommandOptions,
        backgroundFlagName: String? = nil
    ) throws {
        if foreground, focusOptions.backgroundDeliveryExplicitlyRequested {
            throw ValidationError("--foreground cannot be combined with \(backgroundFlagName ?? "--focus-background")")
        }

        if focusOptions.backgroundDeliveryExplicitlyRequested, focusOptions.hasForegroundFocusOverrides {
            throw ValidationError("\(backgroundFlagName ?? "--focus-background") cannot be combined with focus options")
        }
    }

    static func shouldUseForeground(foreground: Bool, focusOptions: FocusCommandOptions) -> Bool {
        foreground || focusOptions.hasForegroundFocusOverrides
    }

    private static func processIdentifierForWindow(windowId: CGWindowID) -> pid_t? {
        guard let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]]
        else {
            return nil
        }

        return windows.first { window in
            self.windowID(from: window[kCGWindowNumber as String]) == windowId
        }.flatMap { window in
            self.pid(from: window[kCGWindowOwnerPID as String])
        }
    }

    private static func windowID(from value: Any?) -> CGWindowID? {
        self.intValue(from: value).map(CGWindowID.init)
    }

    private static func pid(from value: Any?) -> pid_t? {
        self.intValue(from: value).map(pid_t.init)
    }

    private static func intValue(from value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let int = value as? Int {
            return int
        }
        if let int32 = value as? Int32 {
            return Int(int32)
        }
        if let uint32 = value as? UInt32 {
            return Int(uint32)
        }
        return nil
    }

    private static func windowCriteriaDescription(target: InteractionTargetOptions) -> String {
        if let windowTitle = target.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !windowTitle.isEmpty {
            return "window title '\(windowTitle)'"
        }
        if let windowIndex = target.windowIndex {
            return "window index \(windowIndex)"
        }
        if let windowId = target.windowId {
            return "window id \(windowId)"
        }
        return "target window"
    }
}
