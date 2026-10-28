import AppKit
import SwiftUI

/// Resolve installed fonts explicitly so missing faces preserve the original UI font.
/// Font files remain on the user's machine and are never bundled with Hush.
enum HushTypography {
    static func font(size: CGFloat, weight: Font.Weight = .regular,
                     design: Font.Design = .default) -> Font {
        let name = weight == .regular ? "BerkeleyMono-Regular" : "BerkeleyMono-Bold"
        guard NSFont(name: name, size: size) != nil else {
            return .system(size: size, weight: weight, design: design)
        }
        return .custom(name, fixedSize: size)
    }

    static func regular(_ size: CGFloat) -> NSFont {
        NSFont(name: "BerkeleyMono-Regular", size: size)
            ?? .systemFont(ofSize: size)
    }
}

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
