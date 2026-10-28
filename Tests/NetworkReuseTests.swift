import XCTest
@testable import HushCore

@MainActor
final class NetworkReuseTests: XCTestCase {
    func testFiveImmediateAppsShareGatesAndRecordStageTimings() async {
        let clock = ReuseClock()
        var basicChecks = 0
        var httpsChecks = 0
        let context: () -> NSDictionary? = { ["generation": 1] }
        let basic = NetworkReadiness(requiredSuccesses: 1, context: context,
                                     probe: { _ in basicChecks += 1; return true },
                                     sleep: { clock.time += $0 }, now: { clock.time })
        let internet = NetworkReadiness(context: context, probe: { _ in httpsChecks += 1; return true },
                                        sleep: { clock.time += $0 }, now: { clock.time })
        let launcher = ReuseLauncher { clock.time += 0.2 }
        let runner = LaunchRunner(launcher: launcher, network: internet, basicNetwork: basic, now: { clock.time })
        let items = [StartupItem(name: "Surge", path: "/Applications/Surge.app", waitForNetwork: true)] +
            (1...4).map { StartupItem(name: "App\($0)", path: "/fixture/\($0).app", waitForNetwork: true) }
        await runner.start(items)?.value
        XCTAssertEqual(basicChecks, 1)
        XCTAssertEqual(httpsChecks, 2)
        XCTAssertEqual(launcher.launched, items.map(\.name))
        // Only half a second of fixed confirmation overhead for all five apps combined.
        XCTAssertEqual(clock.time, 1.5, accuracy: 0.001)
        XCTAssertEqual(runner.records.compactMap(\.timing).reduce(0) { $0 + $1.network }, 0.5, accuracy: 0.001)
        XCTAssertTrue(runner.records.allSatisfy { abs(($0.timing?.launch ?? 0) - 0.2) < 0.001 })
        // A second run must freshly validate rather than inherit the prior result.
        await runner.start(items)?.value
        XCTAssertEqual(httpsChecks, 4)
        XCTAssertEqual(basicChecks, 2)
    }

    func testCacheExpiresAndContextChangeForcesFreshConfirmation() async throws {
        let clock = ReuseClock()
        var generation = 1
        var checks = 0
        let gate = NetworkReadiness(context: { ["generation": generation] },
                                    probe: { _ in checks += 1; return true },
                                    sleep: { clock.time += $0 }, now: { clock.time })
        _ = try await gate.waitUntilReady(whileNeeded: { true }, progress: { _ in })
        _ = try await gate.waitUntilReady(whileNeeded: { true }, progress: { _ in })
        XCTAssertEqual(checks, 2)
        generation = 2
        _ = try await gate.waitUntilReady(whileNeeded: { true }, progress: { _ in })
        XCTAssertEqual(checks, 4)
        clock.time += 15
        _ = try await gate.waitUntilReady(whileNeeded: { true }, progress: { _ in })
        XCTAssertEqual(checks, 6)
        gate.reset()
    }

    func testUnavailableContextCannotCreateReusableSuccess() async throws {
        let clock = ReuseClock()
        var checks = 0
        let gate = NetworkReadiness(context: { nil }, probe: { _ in checks += 1; return true },
                                    sleep: { clock.time += $0 }, now: { clock.time })
        for _ in 0..<2 { _ = try await gate.waitUntilReady(whileNeeded: { true }, progress: { _ in }) }
        XCTAssertEqual(checks, 4)
        gate.reset()
    }

    func testNetworkChangeBetweenSamplesRestartsConfirmation() async throws {
        let clock = ReuseClock()
        var checks = 0
        let gate = NetworkReadiness(context: { ["generation": checks < 2 ? 1 : 2] },
                                    probe: { _ in checks += 1; return true },
                                    sleep: { clock.time += $0 }, now: { clock.time })
        _ = try await gate.waitUntilReady(whileNeeded: { true }, progress: { _ in })
        XCTAssertEqual(checks, 3)
        gate.reset()
    }

    func testFailuresBackOffButSuccessfulConfirmationIsFast() async throws {
        let clock = ReuseClock()
        var outcomes = [false, false, false, true, true]
        var pauses: [TimeInterval] = []
        let gate = NetworkReadiness(context: { ["generation": 1] }, probe: { _ in outcomes.removeFirst() },
                                    sleep: { pauses.append($0); clock.time += $0 }, now: { clock.time })
        _ = try await gate.waitUntilReady(whileNeeded: { true }, progress: { _ in })
        XCTAssertEqual(pauses, [1, 2, 4, 0.5])
        gate.reset()
    }

    func testOldHistoryDecodesWithoutTimings() throws {
        let data = Data("[{\"id\":\"E5866D36-4DD6-497B-BD00-69744F4CB109\",\"date\":0,\"name\":\"Old\",\"detail\":\"Started\",\"failed\":false}]".utf8)
        let records = try JSONDecoder().decode([RunRecord].self, from: data)
        XCTAssertNil(records[0].timing)
    }
}

@MainActor private final class ReuseClock { var time: TimeInterval = 0 }
@MainActor private final class ReuseLauncher: ApplicationLaunching {
    var launched: [String] = []
    let onLaunch: () -> Void
    init(onLaunch: @escaping () -> Void) { self.onLaunch = onLaunch }
    func isRunning(_ item: StartupItem) -> Bool { false }
    func launch(_ item: StartupItem) async throws -> String {
        launched.append(item.name)
        onLaunch()
        return "Started"
    }
}
