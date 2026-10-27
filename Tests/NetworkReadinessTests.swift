import XCTest
@testable import HushCore

@MainActor
final class NetworkReadinessTests: XCTestCase {
    private func item(_ name: String, waits: Bool = true, delay: Int = 0) -> StartupItem {
        StartupItem(name: name, path: "/Applications/\(name).app", delay: delay, waitForNetwork: waits)
    }

    func testRequiresConsecutiveSuccessesAndResetsAfterFailure() async throws {
        let clock = TestClock()
        var results = [true, false, true, true, true]
        var counts: [Int] = []
        let gate = NetworkReadiness(probe: { _ in results.removeFirst() },
                                    sleep: { clock.advance($0) }, now: { clock.time })
        let ready = try await gate.waitUntilReady(whileNeeded: { true }, progress: { counts.append($0) })
        XCTAssertTrue(ready)
        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(clock.time, 20)
        XCTAssertEqual(counts.filter { $0 == 3 }.count, 1)
    }

    func testProbeErrorsRetryAndTimeoutContinuesLocalApplication() async {
        let clock = TestClock()
        var timeouts: [TimeInterval] = []
        let gate = NetworkReadiness(timeout: 12, probe: {
            timeouts.append($0)
            throw URLError(.notConnectedToInternet)
        }, sleep: { clock.advance($0) }, now: { clock.time })
        let launcher = NetworkTestLauncher()
        let runner = LaunchRunner(launcher: launcher, network: gate)
        await runner.start([item("Online"), item("Local", waits: false)])?.value
        XCTAssertEqual(launcher.launched, ["Local"])
        XCTAssertEqual(clock.time, 12)
        XCTAssertEqual(timeouts, [8, 7, 2])
        XCTAssertEqual(runner.records.filter(\.failed).count, 1)
        XCTAssertTrue(runner.records.first(where: { $0.failed })?.detail.contains("12 秒") == true)
        XCTAssertFalse(runner.isRunning)
    }

    func testLateSuccessCannotBypassDeadline() async {
        let clock = TestClock()
        let gate = NetworkReadiness(timeout: 5, requiredSuccesses: 1, probe: { _ in
            clock.advance(5)
            return true
        }, now: { clock.time })
        do {
            _ = try await gate.waitUntilReady(whileNeeded: { true }, progress: { _ in })
            XCTFail("A response arriving at the deadline must not launch the application")
        } catch { XCTAssertTrue(error.localizedDescription.contains("超时")) }
    }

    func testDelayThenNetworkThenLaunchAndNoProbesForOptOut() async {
        let clock = TestClock()
        var events: [String] = []
        let gate = NetworkReadiness(probe: { _ in events.append("probe"); return true },
                                    sleep: { clock.advance($0) }, now: { clock.time })
        let launcher = NetworkTestLauncher()
        launcher.onLaunch = { events.append("launch:\($0)") }
        let runner = LaunchRunner(launcher: launcher, network: gate, sleep: { events.append("delay:\($0)") })
        await runner.start([item("Online", delay: 3), item("Local", waits: false)])?.value
        XCTAssertEqual(events, ["delay:3", "probe", "probe", "probe", "launch:Online", "launch:Local"])
        XCTAssertTrue(runner.records.first(where: { $0.name == "Online" })?.detail.contains("网络检测已通过") == true)
    }

    func testUserOpenedApplicationDuringProbeSkipsNetworkWait() async {
        let launcher = NetworkTestLauncher()
        var probes = 0
        let gate = NetworkReadiness(probe: { _ in
            probes += 1
            launcher.running.insert("Online")
            return false
        })
        let runner = LaunchRunner(launcher: launcher, network: gate)
        await runner.start([item("Online"), item("Local", waits: false)])?.value
        XCTAssertEqual(probes, 1)
        XCTAssertEqual(launcher.launched, ["Local"])
        XCTAssertEqual(runner.records.first(where: { $0.name == "Online" })?.detail, "已在运行，跳过")
    }

    func testNetworkProvidersWaitForBasicLinkWithoutHTTPSProbes() async {
        let launcher = NetworkTestLauncher()
        let clock = TestClock()
        var basicProbes = 0
        let gate = NetworkReadiness(probe: { _ in XCTFail("Network tools must not use HTTPS"); return false })
        let basic = NetworkReadiness(probe: { _ in basicProbes += 1; return true },
                                     sleep: { clock.advance($0) }, now: { clock.time })
        let runner = LaunchRunner(launcher: launcher, network: gate, basicNetwork: basic)
        let tools = [
            StartupItem(name: "Surge", path: "/Applications/Surge.app", waitForNetwork: true),
            StartupItem(name: "Tailscale", path: "/moved/Tailscale.app", bundleIdentifier: "io.tailscale.ipn.macsys", waitForNetwork: true),
            StartupItem(name: "Tailscale Store", path: "/moved/Tailscale.app", bundleIdentifier: "io.tailscale.ipn.macos", waitForNetwork: true)
        ]
        await runner.start(tools)?.value
        XCTAssertEqual(launcher.launched, tools.map(\.name))
        XCTAssertEqual(basicProbes, 9)
        XCTAssertTrue(runner.records.allSatisfy { $0.detail.contains("基础网络检测已通过") })
        XCTAssertEqual(runner.records.filter(\.failed).count, 0)
        XCTAssertTrue(tools.allSatisfy(\.waitForNetwork)) // No rewrite of the user's preferences.
    }

    func testNetworkProviderRunsBeforeEarlierDependentWithoutRewritingOrder() async {
        let clock = TestClock()
        let launcher = NetworkTestLauncher()
        let gate = NetworkReadiness(probe: { _ in launcher.running.contains("Surge") },
                                    sleep: { clock.advance($0) }, now: { clock.time })
        launcher.onLaunch = { launcher.running.insert($0) }
        let basic = NetworkReadiness(probe: { _ in true }, sleep: { clock.advance($0) }, now: { clock.time })
        let runner = LaunchRunner(launcher: launcher, network: gate, basicNetwork: basic)
        let items = [item("Dependent"), StartupItem(name: "Surge", path: "/Applications/Surge.app", waitForNetwork: true)]
        await runner.start(items)?.value
        XCTAssertEqual(launcher.launched, ["Surge", "Dependent"])
        XCTAssertEqual(items.map(\.name), ["Dependent", "Surge"])
        XCTAssertEqual(runner.records.filter(\.failed).count, 0)
    }

    func testUnselectedNetworkToolLaunchesWithoutAnyProbes() async {
        let launcher = NetworkTestLauncher()
        let never = NetworkReadiness(probe: { _ in XCTFail("Unchecked item must not probe"); return false })
        let runner = LaunchRunner(launcher: launcher, network: never, basicNetwork: never)
        await runner.start([StartupItem(name: "Surge", path: "/Applications/Surge.app", waitForNetwork: false)])?.value
        XCTAssertEqual(launcher.launched, ["Surge"])
    }

    func testBasicNetworkFailureDoesNotLaunchToolOrUseHTTPS() async {
        let clock = TestClock()
        let launcher = NetworkTestLauncher()
        let basic = NetworkReadiness(timeout: 10, conditionName: "基础网络就绪", failureHint: "请检查 Wi-Fi 或有线连接。",
                                     probe: { _ in false }, sleep: { clock.advance($0) }, now: { clock.time })
        let internet = NetworkReadiness(probe: { _ in XCTFail("Must not require internet for a network tool"); return false })
        let runner = LaunchRunner(launcher: launcher, network: internet, basicNetwork: basic)
        await runner.start([StartupItem(name: "Surge", path: "/Applications/Surge.app", waitForNetwork: true),
                            item("Local", waits: false)])?.value
        XCTAssertEqual(launcher.launched, ["Local"])
        XCTAssertTrue(runner.records.first(where: \.failed)?.detail.contains("基础网络就绪超时") == true)
    }

    func testCancelWhileWaitingForBasicNetworkStopsQueue() async {
        let entered = expectation(description: "basic network probe started")
        let basic = NetworkReadiness(probe: { _ in
            entered.fulfill()
            try await Task.sleep(nanoseconds: 60_000_000_000)
            return true
        })
        let launcher = NetworkTestLauncher()
        let runner = LaunchRunner(launcher: launcher, basicNetwork: basic)
        let task = runner.start([StartupItem(name: "Surge", path: "/Applications/Surge.app", waitForNetwork: true)])
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertTrue(runner.status.contains("基础网络就绪"))
        runner.cancel()
        await task?.value
        XCTAssertTrue(launcher.launched.isEmpty)
        XCTAssertFalse(runner.isRunning)
    }

    func testAlreadyRunningItemDoesNotProbe() async {
        let launcher = NetworkTestLauncher()
        launcher.running.insert("Online")
        let gate = NetworkReadiness(probe: { _ in XCTFail("Already running"); return false })
        let runner = LaunchRunner(launcher: launcher, network: gate)
        await runner.start([item("Online")])?.value
        XCTAssertTrue(launcher.launched.isEmpty)
    }

    func testCancelDuringProbePreventsLaunchAndNextRunWorks() async {
        let entered = expectation(description: "probe started")
        let gate = NetworkReadiness(probe: { _ in
            entered.fulfill()
            try await Task.sleep(nanoseconds: 60_000_000_000)
            return true
        })
        let launcher = NetworkTestLauncher()
        let runner = LaunchRunner(launcher: launcher, network: gate)
        let task = runner.start([item("Online"), item("Never", waits: false)])
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertTrue(runner.status.contains("等待网络"))
        runner.cancel()
        await task?.value
        XCTAssertTrue(launcher.launched.isEmpty)
        XCTAssertFalse(runner.isRunning)
        await runner.start([item("Local", waits: false)])?.value
        XCTAssertEqual(launcher.launched, ["Local"])
    }

    func testCancelDuringRetrySleepPreventsLaunch() async {
        let entered = expectation(description: "retry sleep started")
        let gate = NetworkReadiness(probe: { _ in false }, sleep: { _ in
            entered.fulfill()
            try await Task.sleep(nanoseconds: 60_000_000_000)
        })
        let launcher = NetworkTestLauncher()
        let runner = LaunchRunner(launcher: launcher, network: gate)
        let task = runner.start([item("Online")])
        await fulfillment(of: [entered], timeout: 2)
        runner.cancel()
        await task?.value
        XCTAssertTrue(launcher.launched.isEmpty)
        XCTAssertFalse(runner.isRunning)
    }

    func testLegacyConfigDefaultsOffAndNewFlagPersists() throws {
        let original = Configuration(items: [item("Online")])
        let data = try JSONEncoder().encode(original)
        XCTAssertTrue(try JSONDecoder().decode(Configuration.self, from: data).items[0].waitForNetwork)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var items = try XCTUnwrap(json["items"] as? [[String: Any]])
        items[0].removeValue(forKey: "waitForNetwork")
        json["items"] = items
        let legacy = try JSONDecoder().decode(Configuration.self, from: JSONSerialization.data(withJSONObject: json)).validated()
        XCTAssertFalse(legacy.items[0].waitForNetwork)
        XCTAssertEqual(legacy.items[0].name, "Online")
    }

    func testProbeRejectsCaptivePortalRedirectAndHTTPError() {
        let url = HTTPSNetworkProbe.url
        let success = Data("<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>".utf8)
        func response(_ status: Int, _ target: URL) -> HTTPURLResponse {
            HTTPURLResponse(url: target, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        }
        XCTAssertTrue(HTTPSNetworkProbe.isSuccessful(data: success, response: response(200, url)))
        XCTAssertFalse(HTTPSNetworkProbe.isSuccessful(data: success, response: response(503, url)))
        XCTAssertFalse(HTTPSNetworkProbe.isSuccessful(data: Data("Login required".utf8), response: response(200, url)))
        XCTAssertFalse(HTTPSNetworkProbe.isSuccessful(data: success, response: response(200, URL(string: "https://example.com/login")!)))
        XCTAssertEqual(url.scheme, "https")
    }
}

@MainActor
private final class TestClock {
    var time: TimeInterval = 0
    func advance(_ seconds: TimeInterval) { time += seconds }
}

@MainActor
private final class NetworkTestLauncher: ApplicationLaunching {
    var running: Set<String> = []
    var launched: [String] = []
    var onLaunch: ((String) -> Void)?
    func isRunning(_ item: StartupItem) -> Bool { running.contains(item.name) }
    func launch(_ item: StartupItem) async throws -> String {
        launched.append(item.name)
        onLaunch?(item.name)
        return "已正常启动"
    }
}
