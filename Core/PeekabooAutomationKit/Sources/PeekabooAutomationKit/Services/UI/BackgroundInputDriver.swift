@preconcurrency import AXorcist
import CoreGraphics
import Darwin
import Foundation
import PeekabooFoundation

/// Synthetic input that targets a process directly instead of the global HID tap.
///
/// This keeps the user's frontmost app and cursor alone. It is best-effort:
/// macOS delivers pid-routed CGEvents differently from hardware events, and
/// some apps ignore background mouse events unless they also expose an AX path.
enum BackgroundInputDriver {
    static func click(
        at point: CGPoint,
        button: MouseButton,
        count: Int,
        targetProcessIdentifier: pid_t) throws
    {
        guard CGPreflightPostEventAccess() else {
            throw PeekabooError.permissionDeniedEventSynthesizing
        }

        guard targetProcessIdentifier > 0, self.isProcessAlive(targetProcessIdentifier) else {
            throw PeekabooError.invalidInput("Target process identifier is not running: \(targetProcessIdentifier)")
        }

        let (downType, upType, cgButton) = Self.eventTypes(for: button)
        let source = CGEventSource(stateID: .hidSystemState)
        let clampedCount = max(1, min(3, count))

        for clickIndex in 1...clampedCount {
            guard
                let down = CGEvent(
                    mouseEventSource: source,
                    mouseType: downType,
                    mouseCursorPosition: point,
                    mouseButton: cgButton),
                let up = CGEvent(
                    mouseEventSource: source,
                    mouseType: upType,
                    mouseCursorPosition: point,
                    mouseButton: cgButton)
            else {
                throw PeekabooError.operationError(message: "Failed to create background mouse events")
            }

            down.setIntegerValueField(.mouseEventClickState, value: Int64(clickIndex))
            up.setIntegerValueField(.mouseEventClickState, value: Int64(clickIndex))
            self.stampRoutingFields(on: down, at: point, targetProcessIdentifier: targetProcessIdentifier)
            self.stampRoutingFields(on: up, at: point, targetProcessIdentifier: targetProcessIdentifier)

            Self.post(down, to: targetProcessIdentifier)
            usleep(30000)
            Self.post(up, to: targetProcessIdentifier)

            if clickIndex < clampedCount {
                usleep(80000)
            }
        }
    }

    static func type(
        _ text: String,
        delayPerCharacter: TimeInterval,
        targetProcessIdentifier: pid_t) throws
    {
        try self.validateTarget(targetProcessIdentifier)

        for character in text {
            try self.typeCharacter(character, targetProcessIdentifier: targetProcessIdentifier)
            if delayPerCharacter > 0 {
                Thread.sleep(forTimeInterval: delayPerCharacter)
            }
        }
    }

    static func typeCharacter(_ character: Character, targetProcessIdentifier: pid_t) throws {
        try self.validateTarget(targetProcessIdentifier)

        if let stroke = self.keyboardStroke(for: character) {
            try self.postKeyboardStroke(stroke, targetProcessIdentifier: targetProcessIdentifier)
            return
        }

        try self.postUnicodeCharacter(character, targetProcessIdentifier: targetProcessIdentifier)
    }

    static func tapKey(
        keyCode: CGKeyCode,
        modifiers: CGEventFlags = [],
        targetProcessIdentifier: pid_t) throws
    {
        try self.validateTarget(targetProcessIdentifier)
        try self.postKeyboardStroke(
            (keyCode: keyCode, flags: modifiers),
            targetProcessIdentifier: targetProcessIdentifier)
    }

    private static func post(_ event: CGEvent, to pid: pid_t) {
        if !SkyLightPerPidEventPost.post(event, to: pid) {
            event.postToPid(pid)
        }
    }

    private static func validateTarget(_ targetProcessIdentifier: pid_t) throws {
        guard CGPreflightPostEventAccess() else {
            throw PeekabooError.permissionDeniedEventSynthesizing
        }

        guard targetProcessIdentifier > 0, self.isProcessAlive(targetProcessIdentifier) else {
            throw PeekabooError.invalidInput("Target process identifier is not running: \(targetProcessIdentifier)")
        }
    }

    private static func postKeyboardStroke(
        _ stroke: (keyCode: CGKeyCode, flags: CGEventFlags),
        targetProcessIdentifier: pid_t) throws
    {
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: false)
        else {
            throw PeekabooError.operationError(message: "Failed to create background keyboard events")
        }

        keyDown.flags = stroke.flags
        keyUp.flags = stroke.flags
        self.stampKeyboardRoutingFields(on: keyDown, targetProcessIdentifier: targetProcessIdentifier)
        self.stampKeyboardRoutingFields(on: keyUp, targetProcessIdentifier: targetProcessIdentifier)
        self.post(keyDown, to: targetProcessIdentifier)
        usleep(1000)
        self.post(keyUp, to: targetProcessIdentifier)
    }

    private static func postUnicodeCharacter(_ character: Character, targetProcessIdentifier: pid_t) throws {
        let string = String(character)
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else {
            throw PeekabooError.operationError(message: "Failed to create background unicode keyboard events")
        }

        let chars = Array(string.utf16)
        chars.withUnsafeBufferPointer { buffer in
            keyDown.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: buffer.baseAddress!)
            keyUp.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: buffer.baseAddress!)
        }

        self.stampKeyboardRoutingFields(on: keyDown, targetProcessIdentifier: targetProcessIdentifier)
        self.stampKeyboardRoutingFields(on: keyUp, targetProcessIdentifier: targetProcessIdentifier)
        self.post(keyDown, to: targetProcessIdentifier)
        usleep(1000)
        self.post(keyUp, to: targetProcessIdentifier)
    }

    private static func keyboardStroke(for character: Character) -> (keyCode: CGKeyCode, flags: CGEventFlags)? {
        let string = String(character)
        guard string.count == 1 else { return nil }

        if let scalar = string.unicodeScalars.first,
           CharacterSet.lowercaseLetters.contains(scalar),
           let keyCode = self.keyCodes[string]
        {
            return (keyCode, [])
        }

        if let scalar = string.unicodeScalars.first,
           CharacterSet.uppercaseLetters.contains(scalar),
           let keyCode = self.keyCodes[string.lowercased()]
        {
            return (keyCode, .maskShift)
        }

        if let keyCode = self.keyCodes[string] {
            return (keyCode, [])
        }

        if let shifted = self.shiftedKeyCodes[character] {
            return (shifted, .maskShift)
        }

        return nil
    }

    private static func stampRoutingFields(
        on event: CGEvent,
        at point: CGPoint,
        targetProcessIdentifier: pid_t)
    {
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(targetProcessIdentifier))

        guard let windowID = self.windowID(containing: point, targetProcessIdentifier: targetProcessIdentifier) else {
            return
        }

        let value = Int64(windowID)
        event.setIntegerValueField(.windowID, value: value)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: value)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: value)
    }

    private static func stampKeyboardRoutingFields(on event: CGEvent, targetProcessIdentifier: pid_t) {
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(targetProcessIdentifier))
    }

    private static func windowID(containing point: CGPoint, targetProcessIdentifier: pid_t) -> CGWindowID? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]]
        else {
            return nil
        }

        for window in windows {
            guard self.pid(from: window[kCGWindowOwnerPID as String]) == targetProcessIdentifier,
                  self.intValue(from: window[kCGWindowLayer as String]) == 0,
                  let windowNumber = self.windowID(from: window[kCGWindowNumber as String]),
                  let boundsValue = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsValue as CFDictionary),
                  bounds.contains(point)
            else {
                continue
            }

            return windowNumber
        }

        return nil
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

    private static func eventTypes(for button: MouseButton) -> (CGEventType, CGEventType, CGMouseButton) {
        switch button {
        case .left:
            (.leftMouseDown, .leftMouseUp, .left)
        case .right:
            (.rightMouseDown, .rightMouseUp, .right)
        case .middle:
            (.otherMouseDown, .otherMouseUp, .center)
        }
    }

    private static func isProcessAlive(_ processIdentifier: pid_t) -> Bool {
        errno = 0
        if kill(processIdentifier, 0) == 0 {
            return true
        }
        return errno == EPERM
    }

    private static let keyCodes: [String: CGKeyCode] = [
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05, "z": 0x06, "x": 0x07,
        "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10,
        "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17, "=": 0x18,
        "9": 0x19, "7": 0x1A, "-": 0x1B, "8": 0x1C, "0": 0x1D, "]": 0x1E, "o": 0x1F, "u": 0x20,
        "[": 0x21, "i": 0x22, "p": 0x23, "l": 0x25, "j": 0x26, "'": 0x27, "k": 0x28, ";": 0x29,
        "\\": 0x2A, ",": 0x2B, "/": 0x2C, "n": 0x2D, "m": 0x2E, ".": 0x2F, "`": 0x32, " ": 0x31,
    ]

    private static let shiftedKeyCodes: [Character: CGKeyCode] = [
        "!": 0x12, "@": 0x13, "#": 0x14, "$": 0x15, "%": 0x17, "^": 0x16, "&": 0x1A, "*": 0x1C,
        "(": 0x19, ")": 0x1D, "_": 0x1B, "+": 0x18, "{": 0x21, "}": 0x1E, "|": 0x2A, ":": 0x29,
        "\"": 0x27, "<": 0x2B, ">": 0x2F, "?": 0x2C, "~": 0x32,
    ]
}

private enum SkyLightPerPidEventPost {
    private typealias PostToPidFn = @convention(c) (pid_t, CGEvent) -> Void

    private static let postToPid: PostToPidFn? = {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
            RTLD_LAZY)
        else {
            return nil
        }
        guard let symbol = dlsym(handle, "SLEventPostToPid") else {
            return nil
        }
        return unsafeBitCast(symbol, to: PostToPidFn.self)
    }()

    @discardableResult
    static func post(_ event: CGEvent, to pid: pid_t) -> Bool {
        guard let postToPid else {
            return false
        }
        postToPid(pid, event)
        return true
    }
}
