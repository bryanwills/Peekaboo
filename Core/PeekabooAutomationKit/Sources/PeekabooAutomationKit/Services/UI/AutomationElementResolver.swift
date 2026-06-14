import AppKit
import ApplicationServices
@preconcurrency import AXorcist
import CoreGraphics
import Foundation
import PeekabooFoundation

enum DetectedElementRootPolicy {
    static let sourceAttribute = "source"
    static let applicationMenuBarSource = "applicationMenuBar"

    static func requiresApplicationRoot(_ element: DetectedElement) -> Bool {
        let role = element.attributes["role"]?.lowercased()
        if role == "axmenubar" || role == "axmenubaritem" {
            return true
        }

        let hasLegacyMenuBarID = element.id.hasPrefix("menu_") || element.id.hasPrefix("menuitem_")
        let isMenu = element.type == .menu || element.type == .menuItem ||
            role == "axmenu" || role == "axmenuitem" || hasLegacyMenuBarID
        guard isMenu else { return false }

        if element.attributes[self.sourceAttribute]?.lowercased() == self.applicationMenuBarSource.lowercased() {
            return true
        }

        // Disk-backed snapshots predate the source marker but retain collector-specific IDs.
        return hasLegacyMenuBarID
    }
}

/// Re-resolves snapshot/query targets to live AX elements for action invocation.
@MainActor
protocol AutomationElementResolving: Sendable {
    func resolve(detectedElement: DetectedElement, windowContext: WindowContext?) -> AutomationElement?
    func resolve(
        detectedElement: DetectedElement,
        windowContext: WindowContext?,
        targetProcessIdentifier: pid_t?) -> AutomationElement?
    func resolve(query: String, windowContext: WindowContext?, requireTextInput: Bool) -> AutomationElement?
    func resolve(
        query: String,
        windowContext: WindowContext?,
        targetProcessIdentifier: pid_t?,
        requireTextInput: Bool) -> AutomationElement?
}

extension AutomationElementResolving {
    func resolve(
        detectedElement: DetectedElement,
        windowContext: WindowContext?,
        targetProcessIdentifier _: pid_t?) -> AutomationElement?
    {
        self.resolve(detectedElement: detectedElement, windowContext: windowContext)
    }

    func resolve(
        query: String,
        windowContext: WindowContext?,
        targetProcessIdentifier _: pid_t?,
        requireTextInput: Bool) -> AutomationElement?
    {
        self.resolve(query: query, windowContext: windowContext, requireTextInput: requireTextInput)
    }
}

@MainActor
protocol AutomationWindowRootResolving: Sendable {
    func root(for windowID: CGWindowID, in application: NSRunningApplication) -> Element?
}

@MainActor
private struct SystemAutomationWindowRootResolver: AutomationWindowRootResolving {
    private let identityService = WindowIdentityService()

    func root(for windowID: CGWindowID, in application: NSRunningApplication) -> Element? {
        self.identityService.findWindow(byID: windowID, in: application)?.element
    }
}

@MainActor
struct AutomationElementResolver: AutomationElementResolving {
    private let windowRootResolver: any AutomationWindowRootResolving

    init(windowRootResolver: any AutomationWindowRootResolving = SystemAutomationWindowRootResolver()) {
        self.windowRootResolver = windowRootResolver
    }

    func resolve(
        detectedElement: DetectedElement,
        windowContext: WindowContext?) -> AutomationElement?
    {
        self.resolve(
            detectedElement: detectedElement,
            windowContext: windowContext,
            targetProcessIdentifier: nil)
    }

    func resolve(
        detectedElement: DetectedElement,
        windowContext: WindowContext?,
        targetProcessIdentifier: pid_t?) -> AutomationElement?
    {
        self.bestElement(
            in: self.roots(
                windowContext: windowContext,
                targetProcessIdentifier: targetProcessIdentifier,
                detectedElement: detectedElement),
            targetProcessIdentifier: targetProcessIdentifier)
        { element in
            guard let descriptor = AXDescriptorReader.describe(element) else { return nil }
            return self.score(descriptor: descriptor, for: detectedElement)
        }
    }

    func resolve(
        query: String,
        windowContext: WindowContext?,
        requireTextInput: Bool = false) -> AutomationElement?
    {
        self.resolve(
            query: query,
            windowContext: windowContext,
            targetProcessIdentifier: nil,
            requireTextInput: requireTextInput)
    }

    func resolve(
        query: String,
        windowContext: WindowContext?,
        targetProcessIdentifier: pid_t?,
        requireTextInput: Bool = false) -> AutomationElement?
    {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return nil }

        return self.bestElement(
            in: self.roots(
                windowContext: windowContext,
                targetProcessIdentifier: targetProcessIdentifier),
            targetProcessIdentifier: targetProcessIdentifier)
        { element in
            guard let descriptor = AXDescriptorReader.describe(element) else { return nil }
            if requireTextInput, !self.isTextInput(role: descriptor.role) {
                return nil
            }
            return self.score(descriptor: descriptor, query: query)
        }
    }

    func roots(
        windowContext: WindowContext?,
        targetProcessIdentifier: pid_t?,
        detectedElement: DetectedElement? = nil) -> [Element]
    {
        guard let app = self.application(
            windowContext: windowContext,
            targetProcessIdentifier: targetProcessIdentifier)
        else {
            return []
        }

        let axApp = AXApp(app)
        if let detectedElement, DetectedElementRootPolicy.requiresApplicationRoot(detectedElement) {
            return [axApp.element]
        }

        if let rawWindowID = windowContext?.windowID {
            guard let windowID = CGWindowID(exactly: rawWindowID),
                  let root = self.windowRootResolver.root(for: windowID, in: app)
            else {
                return []
            }
            return [root]
        }

        let windows = axApp.windows() ?? []

        if let title = windowContext?.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty,
           let match = windows.first(where: { $0.title() == title })
        {
            return [match, axApp.element]
        }

        if let focused = axApp.focusedWindow() {
            return [focused] + windows + [axApp.element]
        }

        return windows + [axApp.element]
    }

    func application(windowContext: WindowContext?, targetProcessIdentifier: pid_t?) -> NSRunningApplication? {
        if let targetProcessIdentifier {
            if let contextProcessIdentifier = windowContext?.applicationProcessId,
               contextProcessIdentifier != targetProcessIdentifier
            {
                return nil
            }

            guard let app = NSRunningApplication(processIdentifier: targetProcessIdentifier),
                  !app.isTerminated
            else {
                return nil
            }
            if let expectedBundleIdentifier = windowContext?.applicationBundleId,
               let actualBundleIdentifier = app.bundleIdentifier,
               expectedBundleIdentifier != actualBundleIdentifier
            {
                return nil
            }
            return app
        }

        if let processId = windowContext?.applicationProcessId,
           let app = NSRunningApplication(processIdentifier: processId)
        {
            return app.isTerminated ? nil : app
        }

        if let bundleIdentifier = windowContext?.applicationBundleId,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        {
            return app
        }

        return NSWorkspace.shared.frontmostApplication
    }

    private func bestElement(
        in roots: [Element],
        targetProcessIdentifier: pid_t? = nil,
        scorer: (Element) -> Int?) -> AutomationElement?
    {
        var visited = 0
        var stack = roots
        var best: Element?
        var bestScore = 0

        while let element = stack.popLast(), visited < 4000 {
            visited += 1

            if let score = scorer(element), score > bestScore {
                best = element
                bestScore = score
            }

            if let children = element.children() {
                stack.append(contentsOf: children.reversed())
            }
        }

        guard let best else { return nil }
        if let targetProcessIdentifier {
            var resolvedProcessIdentifier: pid_t = 0
            guard AXUIElementGetPid(best.underlyingElement, &resolvedProcessIdentifier) == .success,
                  resolvedProcessIdentifier == targetProcessIdentifier
            else {
                return nil
            }
        }
        return AutomationElement(best)
    }

    private func score(descriptor: AXDescriptorReader.Descriptor, for element: DetectedElement) -> Int? {
        var score = 0
        let candidates = self.candidates(from: descriptor)
        let elementCandidates = [
            element.attributes["identifier"],
            element.label,
            element.value,
            element.attributes["title"],
            element.attributes["description"],
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        if let identifier = element.attributes["identifier"]?.lowercased(),
           descriptor.identifier?.lowercased() == identifier
        {
            score += 500
        }

        for candidate in elementCandidates where candidates.contains(candidate) {
            score += 180
        }

        if self.elementType(element.type, matchesRole: descriptor.role) {
            score += 50
        }

        score += self.frameScore(descriptor.frame, element.bounds)

        return score >= 180 ? score : nil
    }

    private func score(descriptor: AXDescriptorReader.Descriptor, query: String) -> Int? {
        var score = 0
        for candidate in self.candidates(from: descriptor) {
            if candidate == query {
                score += 300
            } else if candidate.contains(query) {
                score += 100
            }
        }

        return score > 0 ? score : nil
    }

    private func candidates(from descriptor: AXDescriptorReader.Descriptor) -> [String] {
        [
            descriptor.identifier,
            descriptor.title,
            descriptor.label,
            descriptor.value,
            descriptor.description,
            descriptor.help,
            descriptor.roleDescription,
            descriptor.placeholder,
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func frameScore(_ lhs: CGRect, _ rhs: CGRect) -> Int {
        guard !lhs.isNull, !rhs.isNull, lhs.width > 0, lhs.height > 0, rhs.width > 0, rhs.height > 0 else {
            return 0
        }

        if lhs.equalTo(rhs) {
            return 250
        }

        let midpointDistance = hypot(lhs.midX - rhs.midX, lhs.midY - rhs.midY)
        if midpointDistance <= 4 {
            return 180
        }
        if midpointDistance <= 12 {
            return 100
        }

        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        let overlap = (intersection.width * intersection.height) / max(
            1,
            min(lhs.width * lhs.height, rhs.width * rhs.height))
        return overlap >= 0.75 ? 100 : 0
    }

    private func elementType(_ type: ElementType, matchesRole role: String) -> Bool {
        let role = role.lowercased()
        switch type {
        case .button:
            return role.contains("button")
        case .textField:
            return self.isTextInput(role: role)
        case .link:
            return role.contains("link")
        case .image:
            return role.contains("image")
        case .slider:
            return role.contains("slider")
        case .checkbox:
            return role.contains("checkbox") || role.contains("check")
        case .menu:
            return role.contains("menu")
        case .group:
            return role.contains("group")
        case .staticText:
            return role.contains("static") || role.contains("text")
        case .radioButton:
            return role.contains("radio")
        case .menuItem:
            return role.contains("menuitem") || role.contains("menu item")
        case .window:
            return role.contains("window")
        case .dialog:
            return role.contains("dialog") || role.contains("sheet")
        case .other:
            return true
        }
    }

    private func isTextInput(role: String) -> Bool {
        let role = role.lowercased()
        return role.contains("textfield") || role.contains("textarea") || role.contains("searchfield")
    }
}
