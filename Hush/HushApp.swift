import AppKit
import SwiftUI
import Carbon
import Combine

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
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private var store: StartupStore!
    private var runner: LaunchRunner!
    private var login: LoginService!
    private var settings: SettingsWindow!
    private var preferences: AppPreferences!
    private var preferenceObservers = Set<AnyCancellable>()
    private var didHandleInitialOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hush", isDirectory: true)
        store = StartupStore(persistence: JSONConfigurationPersistence(url: support.appendingPathComponent("startup.json")))
        runner = LaunchRunner(launcher: SystemLauncher(), historyURL: support.appendingPathComponent("history.json"))
        login = LoginService()
        preferences = AppPreferences()
        settings = SettingsWindow(login: login, preferences: preferences)
        applyDockPreference()
        preferences.$showDockIcon.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            self?.applyDockPreference()
        }.store(in: &preferenceObservers)
        preferences.$showMenuBarIcon.dropFirst().receive(on: RunLoop.main).sink { [weak self] visible in
            self?.statusItem?.isVisible = visible
        }.store(in: &preferenceObservers)
        preferences.$language.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            self?.installMenu()
        }.store(in: &preferenceObservers)
        NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in
                self?.preferences.objectWillChange.send()
                self?.installMenu()
            }.store(in: &preferenceObservers)
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
        if statusItem == nil { statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) }
        if let image = NSImage(systemSymbolName: "square.stack", accessibilityDescription: "Hush") {
            image.isTemplate = true
            statusItem.button?.image = image
        }
        statusItem.isVisible = preferences.showMenuBarIcon
        let menu = NSMenu()
        menu.font = NSFont(name: "BerkeleyMono-Regular", size: menu.font.pointSize) ?? menu.font
        menu.autoenablesItems = false
        menu.delegate = self
        populateMenu(menu)
        statusItem.menu = menu
        let main = NSMenu()
        let application = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.font = NSFont(name: "BerkeleyMono-Regular", size: appMenu.font.pointSize) ?? appMenu.font
        appMenu.addItem(item("关于 Hush", action: #selector(showAbout)))
        appMenu.addItem(item("设置", action: #selector(showSettings), key: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(item("退出 Hush", action: #selector(quit), key: "q"))
        application.submenu = appMenu
        main.addItem(application)
        NSApp.mainMenu = main
    }

    func menuNeedsUpdate(_ menu: NSMenu) { populateMenu(menu) }

    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(item("打开 Hush", action: #selector(showWindow)))
        menu.addItem(.separator())
        if runner.isRunning {
            let progress = NSMenuItem(title: L10n.text(runner.status, language: preferences.effectiveLanguage), action: nil, keyEquivalent: "")
            progress.isEnabled = false
            menu.addItem(progress)
            menu.addItem(item("停止本次启动", action: #selector(stop)))
        } else {
            let launch = item("启动已启用的应用", action: #selector(runAll))
            launch.isEnabled = !store.loadFailed && store.items.contains(where: \.enabled)
            menu.addItem(launch)
        }
        menu.addItem(.separator())
        menu.addItem(item("设置", action: #selector(showSettings), key: ","))
        menu.addItem(item("关于 Hush", action: #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(item("退出 Hush", action: #selector(quit), key: "q"))
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let result = NSMenuItem(title: L10n.text(title, language: preferences.effectiveLanguage), action: action, keyEquivalent: key)
        result.target = self
        return result
    }

    @objc func showWindow() {
        guard store != nil else { return }
        if window == nil {
            let content = MainView(store: store, runner: runner, preferences: preferences, login: login, openSettings: { [weak self] in self?.showSettings() })
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.title = "Hush"
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 860, height: 580)
            window.contentView = NSHostingView(rootView: content)
            window.center()
            self.window = window
        }
        login.refresh()
        NSApp.activate(ignoringOtherApps: true)
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        window?.makeKeyAndOrderFront(nil)
    }

    private func applyDockPreference() {
        let keyWindow = NSApp.keyWindow
        let active = NSApp.isActive
        NSApp.setActivationPolicy(preferences.showDockIcon ? .regular : .accessory)
        if active {
            NSApp.activate(ignoringOtherApps: true)
            keyWindow?.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func showSettings() { settings.show() }
    @objc private func showAbout() { settings.show(.about) }

    @objc private func runAll() { if !store.loadFailed { runner.start(store.items) } }
    @objc private func stop() { runner.cancel() }
    @objc private func quit() { runner.cancel(); NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
