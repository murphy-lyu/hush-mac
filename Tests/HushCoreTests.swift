import XCTest
@testable import HushCore

@MainActor
final class HushCoreTests: XCTestCase {
    func makeItem(_ name: String, enabled: Bool = true, delay: Int = 0) -> StartupItem {
        StartupItem(name: name, path: "/Applications/\(name).app", bundleIdentifier: "test.\(name)", enabled: enabled, delay: delay)
    }

    func testOrderDelaysDisabledAndRunningItems() async {
        let launcher = FakeLauncher()
        launcher.running = ["Existing"]
        var waits: [Int] = []
        let runner = LaunchRunner(launcher: launcher, sleep: { waits.append($0) })
        let task = runner.start([makeItem("A", delay: 3), makeItem("Disabled", enabled: false),
                                 makeItem("Existing", delay: 30), makeItem("B", delay: 5)])
        await task?.value
        XCTAssertEqual(launcher.launched, ["A", "B"])
        XCTAssertEqual(waits, [3, 5])
        XCTAssertEqual(runner.records.count, 3)
        XCTAssertFalse(runner.isRunning)
    }

    func testApplicationOpenedDuringDelayIsSkipped() async {
        let launcher = FakeLauncher()
        let runner = LaunchRunner(launcher: launcher, sleep: { _ in launcher.running.insert("A") })
        await runner.start([makeItem("A", delay: 5)])?.value
        XCTAssertTrue(launcher.launched.isEmpty)
        XCTAssertEqual(runner.records.first?.detail, "已在运行，跳过")
    }

    func testFailureDoesNotBlockFollowingApplications() async {
        let launcher = FakeLauncher()
        launcher.failNames = ["Bad"]
        let runner = LaunchRunner(launcher: launcher)
        await runner.start([makeItem("Bad"), makeItem("Good")])?.value
        XCTAssertEqual(launcher.launched, ["Bad", "Good"])
        XCTAssertEqual(runner.records.filter(\.failed).count, 1)
        XCTAssertTrue(runner.status.contains("1 项失败"))
    }

    func testTestButtonIncludesDisabledItem() async {
        let launcher = FakeLauncher()
        let runner = LaunchRunner(launcher: launcher)
        await runner.start([makeItem("A", enabled: false)], test: true)?.value
        XCTAssertEqual(launcher.launched, ["A"])
    }

    func testCancelDuringDelayPreventsLaunchAndAllowsNextRun() async {
        let launcher = FakeLauncher()
        let runner = LaunchRunner(launcher: launcher)
        let task = runner.start([makeItem("A", delay: 300), makeItem("B")])
        await Task.yield()
        runner.cancel()
        await task?.value
        XCTAssertTrue(launcher.launched.isEmpty)
        XCTAssertFalse(runner.isRunning)
        await runner.start([makeItem("C")])?.value
        XCTAssertEqual(launcher.launched, ["C"])
    }

    func testConcurrentStartRejected() async {
        let launcher = FakeLauncher()
        let runner = LaunchRunner(launcher: launcher)
        let first = runner.start([makeItem("A", delay: 300)])
        XCTAssertNil(runner.start([makeItem("B")]))
        runner.cancel()
        await first?.value
        XCTAssertTrue(launcher.launched.isEmpty)
    }

    func testConfigurationRoundTripMoveDuplicateAndRemoval() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = JSONConfigurationPersistence(url: directory.appendingPathComponent("startup.json"))
        let store = StartupStore(persistence: persistence)
        let a = makeItem("A", delay: 15)
        let b = makeItem("B")
        store.add(a); store.add(b); store.add(a)
        XCTAssertEqual(store.items.count, 2)
        store.move(b.id, by: -1)
        store.move(b.id, by: -1)
        store.update(a.id) { $0.hidden = false; $0.enabled = false }
        let restored = StartupStore(persistence: persistence)
        XCTAssertEqual(restored.items.map(\.name), ["B", "A"])
        XCTAssertFalse(restored.items[1].hidden)
        XCTAssertFalse(restored.items[1].enabled)
        XCTAssertEqual(restored.items[1].delay, 15)
        restored.remove(b.id)
        XCTAssertEqual(try persistence.load().items.map(\.name), ["A"])
    }

    func testNoOpMutationDoesNotWriteOrPublish() async {
        let persistence = MemoryPersistence()
        let store = StartupStore(persistence: persistence)
        let item = makeItem("A")
        store.add(item)
        let saves = persistence.saveCount
        var publications = 0
        let subscription = store.$configuration.sink { _ in publications += 1 }
        store.update(item.id) { $0.delay = item.delay }
        store.remove(UUID())
        XCTAssertEqual(persistence.saveCount, saves)
        XCTAssertEqual(publications, 1)
        withExtendedLifetime(subscription) {}
    }

    func testSaveFailureDoesNotCommitAndLoadFailureDoesNotOverwrite() async {
        let failedSave = MemoryPersistence()
        failedSave.failSave = true
        let store = StartupStore(persistence: failedSave)
        store.add(makeItem("A"))
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNotNil(store.error)
        let failedLoad = MemoryPersistence()
        failedLoad.failLoad = true
        let broken = StartupStore(persistence: failedLoad)
        broken.add(makeItem("B"))
        XCTAssertTrue(broken.loadFailed)
        XCTAssertEqual(failedLoad.saveCount, 0)
    }

    func testInvalidDelayAndUnknownVersionRejected() async {
        XCTAssertThrowsError(try Configuration(items: [makeItem("A", delay: -1)]).validated())
        XCTAssertThrowsError(try Configuration(items: [makeItem("A", delay: 301)]).validated())
        XCTAssertThrowsError(try Configuration(version: 2).validated())
        let a = makeItem("A")
        XCTAssertThrowsError(try Configuration(items: [a, a]).validated())
    }

    func testHistoryPersistsAndIsBounded() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.json")
        let runner = LaunchRunner(launcher: FakeLauncher(), historyURL: url)
        await runner.start((0..<105).map { makeItem("App\($0)") })?.value
        XCTAssertEqual(runner.records.count, 100)
        let restored = LaunchRunner(launcher: FakeLauncher(), historyURL: url)
        XCTAssertEqual(restored.records.count, 100)
        restored.clearHistory()
        XCTAssertTrue(LaunchRunner(launcher: FakeLauncher(), historyURL: url).records.isEmpty)
    }
}

@MainActor
private final class FakeLauncher: ApplicationLaunching {
    var running: Set<String> = []
    var failNames: Set<String> = []
    var launched: [String] = []
    func isRunning(_ item: StartupItem) -> Bool { running.contains(item.name) }
    func launch(_ item: StartupItem) async throws -> String {
        launched.append(item.name)
        if failNames.contains(item.name) { throw HushError.message("测试失败") }
        return item.hidden ? "已隐藏启动" : "已正常启动"
    }
}

private final class MemoryPersistence: ConfigurationPersistence {
    var failLoad = false
    var failSave = false
    var saveCount = 0
    func load() throws -> Configuration {
        if failLoad { throw HushError.message("读取失败") }
        return Configuration()
    }
    func save(_ configuration: Configuration) throws {
        saveCount += 1
        if failSave { throw HushError.message("写入失败") }
    }
}
