import AppKit
@main enum ProbeMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = ProbeDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
@MainActor final class ProbeDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 320, height: 180), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Hush 启动验证"
        window.makeKeyAndOrderFront(nil)
    }
}
