import AppKit
import SwiftUI

@main enum VerifyUI {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.appearance = NSAppearance(named: CommandLine.arguments.contains("--dark") ? .darkAqua : .aqua)
        let store = StartupStore(persistence: PreviewPersistence())
        let runner = LaunchRunner(launcher: PreviewLauncher())
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: CommandLine.arguments.contains("--compact") ? 860 : 920, height: CommandLine.arguments.contains("--compact") ? 580 : 640),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Hush UI Regression"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: CommandLine.arguments.contains("--dark") ? .darkAqua : .aqua)
        let login = LoginService(allowsSystemChanges: false)
        login.setEnabled(true) // Must be a no-op in a test process.
        precondition(!login.enabled && !login.needsApproval)
        let defaults = UserDefaults(suiteName: "com.murphy.hush.qa.preferences")!
        defaults.removePersistentDomain(forName: "com.murphy.hush.qa.preferences")
        let preferences = AppPreferences(defaults: defaults)
        if CommandLine.arguments.contains("--zh") { preferences.language = .simplifiedChinese }
        if CommandLine.arguments.contains("--zh-hant") { preferences.language = .traditionalChinese }
        let settings = SettingsWindow(login: login, preferences: preferences)
        window.contentView = NSHostingView(rootView: MainView(store: store, runner: runner, preferences: preferences, login: login, openSettings: { settings.show() }))
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        var ticks = 0
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
            MainActor.assumeIsolated {
                ticks += 1
                if ticks <= 40 {
                    let index = ticks % store.items.count
                    let id = store.items[index].id
                    store.update(id) { $0.delay = ticks % 2 == 0 ? 0 : 15; $0.waitForNetwork.toggle() }
                    if ticks % 4 == 0 { store.move(id, by: index == 0 ? 1 : -1) }
                }
                if ticks == 60 {
                    timer.invalidate()
                    print("PASS: 60 UI heartbeat ticks, 40 model edits, 10 reorders")
                    fflush(stdout)
                    if !CommandLine.arguments.contains("--keep-open") { exit(0) }
                }
            }
        }
        withExtendedLifetime((store, runner, window, settings, preferences)) { app.run() }
    }
}

private final class PreviewPersistence: ConfigurationPersistence {
    func load() throws -> Configuration {
        Configuration(items: ["Fantastical", "Surge", "Tailscale", "Mail", "Transsioner", "ChatGPT", "Android Studio"].map {
            let path: String
            switch $0 {
            case "Transsioner": path = "/Applications/Lark.app"
            case "Mail": path = "/System/Applications/Mail.app"
            default: path = "/Applications/\($0).app"
            }
            return StartupItem(name: $0, path: path, waitForNetwork: true)
        })
    }
    func save(_ configuration: Configuration) throws {}
}
@MainActor private final class PreviewLauncher: ApplicationLaunching {
    func isRunning(_ item: StartupItem) -> Bool { false }
    func launch(_ item: StartupItem) async throws -> String { "测试夹具；不启动实际应用" }
}
