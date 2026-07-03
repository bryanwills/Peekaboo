//
//  ElementHighlightView.swift
//  Peekaboo
//
//  A single detected-element highlight: accent outline plus an ID tag.
//

import SwiftUI

/// Element-detection feedback: an accent outline sized exactly to the element
/// with a small ID tag above it, replacing the old free-floating orange boxes.
struct ElementHighlightView: View {
    let elementID: String
    let size: CGSize
    let duration: TimeInterval

    @State private var highlightScale: CGFloat = 1.05
    @State private var highlightOpacity: Double = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(VisualizerTheme.accent, lineWidth: 2)
                .frame(width: self.size.width, height: self.size.height)
                .shadow(color: VisualizerTheme.accent.opacity(0.35), radius: 6)

            Text(self.elementID)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(VisualizerTheme.hudText)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .hudChip(cornerRadius: 6)
                .offset(y: -(self.size.height / 2) - 16)
        }
        .scaleEffect(self.highlightScale)
        .opacity(self.highlightOpacity)
        .onAppear {
            withAnimation(VisualizerMotion.pop()) {
                self.highlightScale = 1.0
                self.highlightOpacity = 1
            }
            withAnimation(VisualizerMotion.exit(0.3).delay(max(self.duration - 0.35, 0.4))) {
                self.highlightOpacity = 0
            }
        }
    }
}

#if DEBUG && !SWIFT_PACKAGE
#Preview {
    ElementHighlightView(
        elementID: "B7",
        size: CGSize(width: 160, height: 44),
        duration: 3.0)
        .frame(width: 260, height: 140)
        .background(Color.gray.opacity(0.3))
}
#endif
