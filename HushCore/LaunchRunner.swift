import Foundation
import Combine

@MainActor
protocol ApplicationLaunching {
    func isRunning(_ item: StartupItem) -> Bool
    func launch(_ item: StartupItem) async throws -> String
}

@MainActor
final class LaunchRunner: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var currentID: UUID?
    @Published private(set) var status = "准备就绪"
    @Published private(set) var records: [RunRecord] = []
    @Published private(set) var historyWarning: String?
    private let basicNetwork: NetworkReadiness
    private let network: NetworkReadiness
    private let launcher: ApplicationLaunching
    private let sleep: (Int) async throws -> Void
    private let now: () -> TimeInterval
    private let historyURL: URL?
    private var task: Task<Void, Never>?
    private var runID = UUID()

    init(launcher: ApplicationLaunching, historyURL: URL? = nil, network: NetworkReadiness? = nil,
         basicNetwork: NetworkReadiness? = nil,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         sleep: @escaping (Int) async throws -> Void = { seconds in
             try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
         }) {
        self.network = network ?? NetworkReadiness()
        self.basicNetwork = basicNetwork ?? NetworkReadiness(requiredSuccesses: 1, conditionName: "基础网络就绪",
            failureHint: "请检查 Wi-Fi 或有线连接是否取得 IP 和网关。", probe: BasicNetworkProbe.check)
        self.launcher = launcher
        self.historyURL = historyURL
        self.sleep = sleep
        self.now = now
        if let historyURL, let data = try? Data(contentsOf: historyURL),
           let saved = try? JSONDecoder().decode([RunRecord].self, from: data) {
            records = Array(saved.prefix(100))
        }
    }

    @discardableResult
    func start(_ items: [StartupItem], test: Bool = false) -> Task<Void, Never>? {
        guard !isRunning else { return nil }
        let selected = test ? items : items.filter(\.enabled)
        // Establish connectivity before an earlier network-dependent item can block it.
        // Stable partition: retain the user's relative order within each group.
        let queue = selected.filter(\.providesNetwork) + selected.filter { !$0.providesNetwork }
        guard !queue.isEmpty else { status = "没有已启用的应用"; return nil }
        let token = UUID()
        runID = token
        isRunning = true
        network.reset()
        basicNetwork.reset()
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.network.reset(); self.basicNetwork.reset() }
            var failures = 0
            for item in queue {
                let began = now()
                var delayed: TimeInterval = 0
                var waited: TimeInterval = 0
                var launched: TimeInterval = 0
                @MainActor func timing() -> LaunchTiming {
                    LaunchTiming(delay: delayed, network: waited, launch: launched, total: now() - began)
                }
                do {
                    try Task.checkCancellation()
                    currentID = item.id
                    if launcher.isRunning(item) {
                        append(name: item.name, detail: "已在运行，跳过")
                        continue
                    }
                    if item.delay > 0 {
                        status = "\(item.name) · 等待 \(item.delay) 秒"
                        let beganDelay = now()
                        try await sleep(item.delay)
                        delayed = now() - beganDelay
                    }
                    try Task.checkCancellation()
                    // The application may have opened while we were waiting.
                    if launcher.isRunning(item) {
                        append(name: item.name, detail: "已在运行，跳过")
                        continue
                    }
                    if item.waitForNetwork {
                        let beganNetwork = now()
                        defer { waited = now() - beganNetwork }
                        let gate = item.providesNetwork ? basicNetwork : network
                        let condition = item.providesNetwork ? "基础网络就绪" : "网络可用"
                        let ready = try await gate.waitUntilReady(whileNeeded: { !self.launcher.isRunning(item) }) { count in
                            let next = "\(item.name) · 等待\(condition)（\(count)/\(gate.requiredSuccesses)，最多 5 分钟）"
                            if self.status != next { self.status = next }
                        }
                        try Task.checkCancellation()
                        if !ready || launcher.isRunning(item) {
                            append(name: item.name, detail: "已在运行，跳过")
                            continue
                        }
                    }
                    status = "正在启动 \(item.name)"
                    let result: String
                    do {
                        let beganLaunch = now()
                        defer { launched = now() - beganLaunch }
                        result = try await launcher.launch(item)
                    }
                    try Task.checkCancellation()
                    let prefix = item.providesNetwork ? "基础网络检测已通过" : "网络检测已通过"
                    append(name: item.name, detail: item.waitForNetwork ? "\(prefix) · \(result)" : result, timing: timing())
                } catch is CancellationError {
                    break
                } catch {
                    failures += 1
                    append(name: item.name, detail: error.localizedDescription, failed: true, timing: timing())
                }
            }
            guard runID == token else { return }
            status = Task.isCancelled ? "已停止；已启动的应用会继续运行" : (failures == 0 ? "本次启动已完成" : "已完成 · \(failures) 项失败，请查看记录")
            isRunning = false
            currentID = nil
            task = nil
        }
        return task
    }

    func cancel() {
        task?.cancel()
        status = "正在停止后续启动…"
    }

    func clearHistory() {
        records = []
        saveHistory()
    }

    private func append(name: String, detail: String, failed: Bool = false, timing: LaunchTiming? = nil) {
        let measured = timing.map { String(format: " · 网络 %.1f 秒 / 启动 %.1f 秒 / 总计 %.1f 秒", $0.network, $0.launch, $0.total) } ?? ""
        records.insert(RunRecord(name: name, detail: detail + measured, failed: failed, timing: timing), at: 0)
        records = Array(records.prefix(100))
        saveHistory()
    }

    private func saveHistory() {
        guard let historyURL else { return }
        do {
            try FileManager.default.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(records).write(to: historyURL, options: .atomic)
            historyWarning = nil
        } catch {
            historyWarning = "启动记录未能保存：\(error.localizedDescription)"
        }
    }
}
