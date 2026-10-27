import AppKit
import SwiftUI
import Carbon

@main
enum HushMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private var store: StartupStore!
    private var runner: LaunchRunner!
    private var login: LoginService!
    private var didHandleInitialOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hush", isDirectory: true)
        store = StartupStore(persistence: JSONConfigurationPersistence(url: support.appendingPathComponent("startup.json")))
        runner = LaunchRunner(launcher: SystemLauncher(), historyURL: support.appendingPathComponent("history.json"))
        login = LoginService()
        installMenu()
        let event = NSAppleEventManager.shared().currentAppleEvent
        let launchedAtLogin = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if launchedAtLogin || CommandLine.arguments.contains("--login") {
            didHandleInitialOpen = true
            if !store.loadFailed { runner.start(store.items) }
        } else {
            didHandleInitialOpen = true
            showWindow()
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(workspaceActivated),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if didHandleInitialOpen { showWindow() }
        return false
    }

    @objc private func workspaceActivated() {
        if NSApp.isActive { login.refresh() }
    }

    private func installMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(systemSymbolName: "square.stack", accessibilityDescription: "Hush") {
            image.isTemplate = true
            statusItem.button?.image = image
        }
        let menu = NSMenu()
        menu.addItem(item("打开 Hush", action: #selector(showWindow), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("启动已启用的应用", action: #selector(runAll)))
        menu.addItem(item("停止后续启动", action: #selector(stop)))
        menu.addItem(.separator())
        menu.addItem(item("退出 Hush", action: #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let result = NSMenuItem(title: title, action: action, keyEquivalent: key)
        result.target = self
        return result
    }

    @objc func showWindow() {
        guard store != nil else { return }
        if window == nil {
            let content = MainView(store: store, runner: runner, login: login)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 640),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "Hush"
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 800, height: 560)
            window.contentView = NSHostingView(rootView: content)
            window.center()
            self.window = window
        }
        login.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func runAll() { if !store.loadFailed { runner.start(store.items) } }
    @objc private func stop() { runner.cancel() }
    @objc private func quit() { runner.cancel(); NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
