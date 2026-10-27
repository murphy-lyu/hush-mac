import AppKit
@main enum Verify {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        Task { @MainActor in
            let launcher = SystemLauncher()
            let path = CommandLine.arguments[1]
            let target = StartupItem(name: "Hush Probe", path: path, bundleIdentifier: "com.murphy.hush.qa.probe")
            do {
                let before = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
                let result = try await launcher.launch(target)
                try await Task.sleep(nanoseconds: 1_000_000_000)
                let launched = NSRunningApplication.runningApplications(withBundleIdentifier: "com.murphy.hush.qa.probe").first!
                let after = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
                print("result=\(result), running=\(launcher.isRunning(target)), hidden=\(launched.isHidden), active=\(launched.isActive), focusBefore=\(before), focusAfter=\(after)")
                let passed = launched.isHidden && !launched.isActive && before == after
                launched.terminate()
                exit(passed ? 0 : 1)
            } catch { print(error); exit(1) }
        }
        app.run()
    }
}
