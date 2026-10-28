import AppKit
import SwiftUI

/// One backdrop per window; content cards only composite translucent fills.
/// Accessibility's Reduce Transparency setting always gets an opaque surface.
struct HushFrostedBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Group {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                WindowBackdrop()
                    .overlay(colorScheme == .dark ? Color.black.opacity(0.10) : Color.white.opacity(0.24))
            }
        }.ignoresSafeArea()
    }
}

private struct WindowBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
