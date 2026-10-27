import AppKit
import Carbon
@main enum Lifecycle {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        Task { @MainActor in
            let url = URL(fileURLWithPath: CommandLine.arguments[1])
            for mode in ["argument", "appleEvent", "normal"] {
                let existing = NSRunningApplication.runningApplications(withBundleIdentifier: "com.murphy.hush")
                for process in existing { process.terminate() }
                for _ in 0..<50 {
                    if NSRunningApplication.runningApplications(withBundleIdentifier: "com.murphy.hush").isEmpty { break }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                let options = NSWorkspace.OpenConfiguration()
                options.activates = mode == "normal"
                if mode == "argument" { options.arguments = ["--login"] }
                if mode == "appleEvent" {
                    let event = NSAppleEventDescriptor(eventClass: kCoreEventClass, eventID: kAEOpenApplication,
                        targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
                    event.setParam(NSAppleEventDescriptor(enumCode: keyAELaunchedAsLogInItem), forKeyword: keyAEPropData)
                    options.appleEvent = event
                }
                do {
                    let process = try await NSWorkspace.shared.openApplication(at: url, configuration: options)
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
                    let owned = windows.filter {
                        ($0[kCGWindowOwnerPID as String] as? Int32) == process.processIdentifier &&
                        ($0[kCGWindowLayer as String] as? Int) == 0
                    }
                    print("\(mode): appRunning=\(!process.isTerminated), normalWindows=\(owned.count)")
                    if mode != "normal" && !owned.isEmpty { print("FAIL: login path opened a window"); exit(1) }
                    if mode == "normal" && owned.isEmpty { print("FAIL: manual launch did not open window"); exit(1) }
                } catch { print(error); exit(1) }
            }
            exit(0)
        }
        app.run()
    }
}
