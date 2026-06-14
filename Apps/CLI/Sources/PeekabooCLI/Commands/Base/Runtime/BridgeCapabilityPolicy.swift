import Foundation
import PeekabooAutomationKit
import PeekabooBridge
import PeekabooFoundation

enum BridgeCapabilityPolicy {
    static func supportsRemoteRequirements(
        for handshake: PeekabooBridgeHandshakeResponse,
        options: CommandRuntimeOptions
    ) -> Bool {
        guard handshake.supportedOperations.contains(.captureScreen) else {
            return false
        }

        if options.requiresElementActions, !self.supportsElementActions(for: handshake) {
            return false
        }

        if options.requiresInspectAccessibilityTree, !self.supportsInspectAccessibilityTree(for: handshake) {
            return false
        }

        if options.requiresBrowserMCP, !self.supportsBrowserMCP(for: handshake) {
            return false
        }

        if options.requiresApplicationLaunchOptions, !self.supportsApplicationLaunchOptions(for: handshake) {
            return false
        }

        if options.requiresApplicationRelaunch, !self.supportsApplicationRelaunch(for: handshake) {
            return false
        }

        if options.requiresSurvivingApplicationHost, handshake.hostKind != .onDemand {
            return false
        }

        if options.requiresHostApplicationInventory, !self.supportsHostApplicationInventory(for: handshake) {
            return false
        }

        if options.requiresExactWindowTargetedClicks,
           !self.supportsExactWindowTargetedClicks(for: handshake) {
            return false
        }

        if options.requiresPostEventClickPermission,
           handshake.permissions?.postEvent != true {
            return false
        }

        if options.requiresImplicitSnapshotInvalidation || options.usesPerToolSnapshotInvalidation,
           !self.supportsImplicitSnapshotInvalidation(for: handshake) {
            return false
        }

        return true
    }

    static func supportsTargetedHotkeys(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        self.targetedHotkeyAvailability(for: handshake).isEnabled
    }

    static func supportsTargetedTypeActions(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        self.targetedTypeAvailability(for: handshake).isEnabled
    }

    static func supportsTargetedClicks(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        self.targetedClickAvailability(for: handshake).isEnabled
    }

    static func supportsApplicationLaunchOptions(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 9) &&
            handshake.supportedOperations.contains(.launchApplicationWithOptions)
    }

    static func supportsApplicationRelaunch(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        guard handshake.hostKind == .onDemand,
              handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 9),
              handshake.supportedOperations.contains(.relaunchApplicationWithOptions)
        else {
            return false
        }

        let enabledOperations = handshake.enabledOperations ?? handshake.supportedOperations
        return enabledOperations.contains(.relaunchApplicationWithOptions)
    }

    static func supportsHostApplicationInventory(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        guard handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 0),
              handshake.supportedOperations.contains(.listApplications)
        else {
            return false
        }

        let enabledOperations = handshake.enabledOperations ?? handshake.supportedOperations
        return enabledOperations.contains(.listApplications)
    }

    static func supportsImplicitSnapshotInvalidation(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        guard handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 9),
              handshake.supportedOperations.contains(.invalidateImplicitLatestSnapshot)
        else {
            return false
        }

        let enabledOperations = handshake.enabledOperations ?? handshake.supportedOperations
        return enabledOperations.contains(.invalidateImplicitLatestSnapshot)
    }

    static func supportsElementActions(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 3) &&
            handshake.supportedOperations.contains(.setValue) &&
            handshake.supportedOperations.contains(.performAction)
    }

    static func supportsDesktopObservation(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 5) &&
            handshake.supportedOperations.contains(.desktopObservation)
    }

    static func supportsInspectAccessibilityTree(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 7) &&
            handshake.supportedOperations.contains(.inspectAccessibilityTree)
    }

    static func supportsBrowserMCP(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 4) &&
            handshake.supportedOperations.contains(.browserStatus) &&
            handshake.supportedOperations.contains(.browserConnect) &&
            handshake.supportedOperations.contains(.browserDisconnect) &&
            handshake.supportedOperations.contains(.browserExecute)
    }

    static func supportsPostEventPermissionRequest(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 2) &&
            handshake.supportedOperations.contains(.requestPostEventPermission)
    }

    static func targetedHotkeyAvailability(for handshake: PeekabooBridgeHandshakeResponse)
    -> (isEnabled: Bool, unavailableReason: String?, missingPermissions: Set<PeekabooBridgePermissionKind>) {
        guard
            handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 1),
            handshake.supportedOperations.contains(.targetedHotkey)
        else {
            return (false, nil, [])
        }

        let enabledOperations = handshake.enabledOperations ?? handshake.supportedOperations
        if enabledOperations.contains(.targetedHotkey) {
            return (true, nil, [])
        }

        let missingPermissions = missingPermissions(for: .targetedHotkey, handshake: handshake)
        guard !missingPermissions.isEmpty else {
            return (
                false,
                "Remote bridge host supports background hotkeys, but they are disabled by current permissions",
                []
            )
        }

        return (
            false,
            "Remote bridge host supports background hotkeys, but current permissions are missing: " +
                self.missingPermissionNames(missingPermissions).joined(separator: ", "),
            missingPermissions
        )
    }

    static func targetedClickAvailability(for handshake: PeekabooBridgeHandshakeResponse)
    -> (isEnabled: Bool, unavailableReason: String?, missingPermissions: Set<PeekabooBridgePermissionKind>) {
        guard
            handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 6),
            handshake.supportedOperations.contains(.targetedClick)
        else {
            return (false, nil, [])
        }

        let enabledOperations = handshake.enabledOperations ?? handshake.supportedOperations
        if enabledOperations.contains(.targetedClick) {
            let missingVariantPermissions: Set<PeekabooBridgePermissionKind> =
                handshake.permissions?.postEvent == false ? [.postEvent] : []
            return (true, nil, missingVariantPermissions)
        }

        let requestAwarePermissions =
            handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 9) &&
            handshake.permissionTags[PeekabooBridgeOperation.targetedClick.rawValue]?.isEmpty == true
        if requestAwarePermissions,
           handshake.permissions?.accessibility == false,
           handshake.permissions?.postEvent == false {
            return (
                false,
                "Remote bridge host background clicks require Accessibility or Event Synthesizing permission",
                []
            )
        }

        let missingPermissions = missingPermissions(for: .targetedClick, handshake: handshake)
        guard !missingPermissions.isEmpty else {
            return (
                false,
                "Remote bridge host supports background clicks, but they are disabled by current permissions",
                []
            )
        }

        return (
            false,
            "Remote bridge host supports background clicks, but current permissions are missing: " +
                self.missingPermissionNames(missingPermissions).joined(separator: ", "),
            missingPermissions
        )
    }

    static func supportsExactWindowTargetedClicks(for handshake: PeekabooBridgeHandshakeResponse) -> Bool {
        guard handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 9),
              handshake.supportedOperations.contains(.exactWindowTargetedClick)
        else {
            return false
        }
        return (handshake.enabledOperations ?? handshake.supportedOperations)
            .contains(.exactWindowTargetedClick)
    }

    static func targetedTypeAvailability(for handshake: PeekabooBridgeHandshakeResponse)
    -> (isEnabled: Bool, unavailableReason: String?, missingPermissions: Set<PeekabooBridgePermissionKind>) {
        guard
            handshake.negotiatedVersion >= PeekabooBridgeProtocolVersion(major: 1, minor: 8),
            handshake.supportedOperations.contains(.targetedTypeActions)
        else {
            return (false, nil, [])
        }

        let enabledOperations = handshake.enabledOperations ?? handshake.supportedOperations
        if enabledOperations.contains(.targetedTypeActions) {
            return (true, nil, [])
        }

        let missingPermissions = missingPermissions(for: .targetedTypeActions, handshake: handshake)
        guard !missingPermissions.isEmpty else {
            return (
                false,
                "Remote bridge host supports background typing, but it is disabled by current permissions",
                []
            )
        }

        return (
            false,
            "Remote bridge host supports background typing, but current permissions are missing: " +
                self.missingPermissionNames(missingPermissions).joined(separator: ", "),
            missingPermissions
        )
    }

    private static func missingPermissions(
        for operation: PeekabooBridgeOperation,
        handshake: PeekabooBridgeHandshakeResponse
    ) -> Set<PeekabooBridgePermissionKind> {
        let requiredPermissions = Set(
            handshake.permissionTags[operation.rawValue] ?? Array(operation.requiredPermissions)
        )
        let grantedPermissions = grantedPermissions(from: handshake.permissions)
        return requiredPermissions.subtracting(grantedPermissions)
    }

    private static func missingPermissionNames(_ permissions: Set<PeekabooBridgePermissionKind>) -> [String] {
        permissions.map(\.displayName).sorted()
    }

    private static func grantedPermissions(from status: PermissionsStatus?) -> Set<PeekabooBridgePermissionKind> {
        guard let status else { return [] }

        var granted: Set<PeekabooBridgePermissionKind> = []
        if status.screenRecording {
            granted.insert(.screenRecording)
        }
        if status.accessibility {
            granted.insert(.accessibility)
        }
        if status.appleScript {
            granted.insert(.appleScript)
        }
        if status.postEvent {
            granted.insert(.postEvent)
        }
        return granted
    }
}

extension PeekabooBridgePermissionKind {
    fileprivate var displayName: String {
        switch self {
        case .screenRecording:
            "Screen Recording"
        case .accessibility:
            "Accessibility"
        case .postEvent:
            "Event Synthesizing"
        case .appleScript:
            "AppleScript"
        }
    }
}
