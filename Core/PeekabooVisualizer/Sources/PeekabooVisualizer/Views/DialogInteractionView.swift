//
//  DialogInteractionView.swift
//  Peekaboo
//
//  An element outline with an action badge; caret pulse for text entry.
//

import PeekabooFoundation
import SwiftUI

/// Dialog-interaction feedback: the target element gets an accent outline and
/// a small badge naming the action. Text entry shows a blinking caret; click
/// actions pulse once. Red is reserved for dismissal.
struct DialogInteractionView: View {
    let element: DialogElementType
    let elementRect: CGRect
    let action: DialogActionType
    let duration: TimeInterval

    @State private var outlineScale: CGFloat = 1.06
    @State private var outlineOpacity: Double = 0
    @State private var badgeScale: CGFloat = 0.5
    @State private var badgeOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0
    @State private var caretVisible = true

    init(element: DialogElementType, elementRect: CGRect, action: DialogActionType, duration: TimeInterval = 1.0) {
        self.element = element
        self.elementRect = elementRect
        self.action = action
        self.duration = duration
    }

    private var tint: Color {
        self.action == .dismiss ? VisualizerTheme.destructive : VisualizerTheme.accent
    }

    var body: some View {
        ZStack {
            // Element outline
            RoundedRectangle(cornerRadius: self.element.outlineCornerRadius, style: .continuous)
                .stroke(self.tint, lineWidth: 2.5)
                .frame(width: self.elementRect.width, height: self.elementRect.height)
                .scaleEffect(self.outlineScale)
                .opacity(self.outlineOpacity)
                .shadow(color: self.tint.opacity(0.4), radius: 8)

            // One-shot press pulse for click-style actions
            if self.action != .enterText {
                RoundedRectangle(cornerRadius: self.element.outlineCornerRadius, style: .continuous)
                    .stroke(self.tint, lineWidth: 1.5)
                    .frame(width: self.elementRect.width, height: self.elementRect.height)
                    .scaleEffect(self.pulseScale)
                    .opacity(self.pulseOpacity)
            }

            // Blinking caret for text entry
            if self.action == .enterText {
                RoundedRectangle(cornerRadius: 1)
                    .fill(self.tint)
                    .frame(width: 2.5, height: min(self.elementRect.height * 0.55, 22))
                    .offset(x: -self.elementRect.width / 2 + 12)
                    .opacity(self.caretVisible && self.outlineOpacity > 0 ? 1 : 0)
            }

            // Action badge above the element
            GlyphBadgeView(systemName: self.action.glyphName, tint: self.tint)
                .scaleEffect(self.badgeScale)
                .opacity(self.badgeOpacity)
                .offset(y: -self.elementRect.height / 2 - 26)
        }
        .onAppear {
            self.animateInteraction()
        }
    }

    private func animateInteraction() {
        // Outline locks onto the element
        withAnimation(VisualizerMotion.pop()) {
            self.outlineScale = 1.0
            self.outlineOpacity = 1
        }
        withAnimation(VisualizerMotion.pop(0.3).delay(0.1)) {
            self.badgeScale = 1.0
            self.badgeOpacity = 1
        }

        if self.action == .enterText {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                self.caretVisible = false
            }
        } else {
            // Single press pulse
            self.pulseOpacity = 0.8
            withAnimation(VisualizerMotion.enter(0.45).delay(0.2)) {
                self.pulseScale = 1.25
                self.pulseOpacity = 0
            }
        }

        withAnimation(VisualizerMotion.exit(0.3).delay(max(self.duration - 0.35, 0.4))) {
            self.outlineOpacity = 0
            self.badgeOpacity = 0
        }
    }
}

// MARK: - Element / Action styling

extension DialogElementType {
    /// Outline rounding tuned to how each control renders on macOS.
    var outlineCornerRadius: CGFloat {
        switch self {
        case .button: 8
        case .textField, .dropdown: 6
        case .checkbox, .radioButton: 4
        case .alert, .other: 10
        }
    }
}

extension DialogActionType {
    var glyphName: String {
        switch self {
        case .clickButton: "cursorarrow.click"
        case .enterText: "character.cursor.ibeam"
        case .toggle: "checkmark.square"
        case .select: "checklist"
        case .handleFileDialog: "folder"
        case .dismiss: "xmark"
        }
    }
}

#if DEBUG && !SWIFT_PACKAGE
#Preview {
    VStack(spacing: 60) {
        DialogInteractionView(
            element: .button,
            elementRect: CGRect(x: 0, y: 0, width: 120, height: 40),
            action: .clickButton,
            duration: 3.0)
            .frame(width: 250, height: 140)
            .background(Color.gray.opacity(0.3))

        DialogInteractionView(
            element: .textField,
            elementRect: CGRect(x: 0, y: 0, width: 220, height: 32),
            action: .enterText,
            duration: 3.0)
            .frame(width: 320, height: 140)
            .background(Color.gray.opacity(0.3))
    }
}
#endif
