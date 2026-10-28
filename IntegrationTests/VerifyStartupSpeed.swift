import Foundation

/// Uses production network gates and a no-op launcher. Does not open user apps or save history.
@main enum VerifyStartupSpeed {
    @MainActor static func main() async {
        let basic = NetworkReadiness(timeout: 40, requiredSuccesses: 1, probe: BasicNetworkProbe.check)
        defer { basic.reset() }
        do {
            _ = try await basic.waitUntilReady(whileNeeded: { true }, progress: { _ in })
            let runner = LaunchRunner(launcher: SpeedLauncher(), network: NetworkReadiness(timeout: 40))
            let items = (1...5).map { StartupItem(name: "Fixture\($0)", path: "/fixture/\($0).app", waitForNetwork: true) }
            let began = ProcessInfo.processInfo.systemUptime
            await runner.start(items)?.value
            guard runner.records.count == 5, !runner.records.contains(where: \.failed) else {
                print("FAIL:", runner.records.map(\.detail)); exit(1)
            }
            for record in runner.records.reversed() { print(record.name, record.detail) }
            print(String(format: "PASS: five no-op launch requests with real network checks in %.3f seconds", ProcessInfo.processInfo.systemUptime - began))
        } catch { print("FAIL:", error.localizedDescription); exit(1) }
    }
}
@MainActor private final class SpeedLauncher: ApplicationLaunching {
    func isRunning(_ item: StartupItem) -> Bool { false }
    func launch(_ item: StartupItem) async throws -> String { "No-op fixture; no user application launched" }
}
