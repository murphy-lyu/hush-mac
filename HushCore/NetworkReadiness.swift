import Foundation
import SystemConfiguration

/// A snapshot of local routing, link, DNS and proxy state. Nothing is logged or persisted.
enum NetworkContext {
    static func snapshot() -> NSDictionary? {
        guard let store = SCDynamicStoreCreate(nil, "com.murphy.hush.network-context" as CFString, nil, nil) else { return nil }
        let keys = ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6",
                    "State:/Network/Global/DNS", "State:/Network/Global/Proxies"]
        let patterns = ["State:/Network/Interface/.*/Link", "State:/Network/Service/.*/IPv4",
                        "State:/Network/Service/.*/IPv6"]
        return SCDynamicStoreCopyMultiple(store, keys as CFArray, patterns as CFArray) as NSDictionary?
    }
}

/// One client per gate; connections can be reused during a run and are closed at its end.
@MainActor
final class HTTPSNetworkProbe {
    static let url = URL(string: "https://www.apple.com/library/test/success.html")!
    private var session: URLSession?
    private var sessionTimeout: TimeInterval?

    func check(timeout: TimeInterval) async throws -> Bool {
        if session == nil || sessionTimeout != timeout {
            close()
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.urlCredentialStorage = nil
            configuration.timeoutIntervalForRequest = timeout
            configuration.timeoutIntervalForResource = timeout
            configuration.waitsForConnectivity = false
            session = URLSession(configuration: configuration)
            sessionTimeout = timeout
        }
        guard let session else { return false }
        var request = URLRequest(url: Self.url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        return Self.isSuccessful(data: data, response: response)
    }

    deinit { session?.invalidateAndCancel() }

    func close() {
        session?.invalidateAndCancel()
        session = nil
        sessionTimeout = nil
    }

    static func isSuccessful(data: Data, response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.url == url,
              let body = String(data: data, encoding: .utf8) else { return false }
        return body.range(of: "<title>Success</title>", options: .caseInsensitive) != nil
    }
}

@MainActor
final class NetworkReadiness {
    let requiredSuccesses: Int
    private let probe: (TimeInterval) async throws -> Bool
    private let client: HTTPSNetworkProbe
    private let sleep: (TimeInterval) async throws -> Void
    private let now: () -> TimeInterval
    private let context: () -> NSDictionary?
    private let timeout: TimeInterval
    private let interval: TimeInterval
    private let retryInterval: TimeInterval
    private let cacheLifetime: TimeInterval
    private let conditionName: String
    private let failureHint: String
    private var success: (time: TimeInterval, context: NSDictionary)?

    init(timeout: TimeInterval = 300, interval: TimeInterval = 0.5, requiredSuccesses: Int = 2,
         conditionName: String = "网络可用", failureHint: String = "请检查网络或代理后重试。",
         retryInterval: TimeInterval = 1, cacheLifetime: TimeInterval = 15,
         context: @escaping () -> NSDictionary? = NetworkContext.snapshot,
         probe: ((TimeInterval) async throws -> Bool)? = nil,
         sleep: @escaping (TimeInterval) async throws -> Void = {
             try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000))
         }, now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        precondition(timeout > 0 && interval > 0 && requiredSuccesses > 0 && retryInterval > 0 && cacheLifetime >= 0)
        let client = HTTPSNetworkProbe()
        self.client = client
        self.probe = probe ?? { try await client.check(timeout: $0) }
        self.conditionName = conditionName
        self.failureHint = failureHint
        self.timeout = timeout
        self.interval = interval
        self.retryInterval = retryInterval
        self.cacheLifetime = cacheLifetime
        self.context = context
        self.requiredSuccesses = requiredSuccesses
        self.sleep = sleep
        self.now = now
    }

    /// Call at both run boundaries. Results never survive into a later test/login run.
    func reset() {
        success = nil
        client.close()
    }

    /// Returns false if the user opened the application while waiting.
    func waitUntilReady(whileNeeded: () -> Bool, progress: (Int) -> Void) async throws -> Bool {
        try Task.checkCancellation()
        guard whileNeeded() else { return false }
        if let cached = success {
            let unchanged = context().map { cached.context.isEqual($0) } ?? false
            if now() - cached.time < cacheLifetime && unchanged {
                progress(requiredSuccesses)
                return true
            }
            // A changed proxy/DNS/path must not keep an old session's connections.
            if !unchanged { client.close() }
        }
        success = nil
        let deadline = now() + timeout
        var successes = 0
        var failures = 0
        var previousContext: NSDictionary?
        while true {
            try Task.checkCancellation()
            guard whileNeeded() else { return false }
            let remaining = deadline - now()
            guard remaining > 0 else { throw timeoutError }
            progress(successes)
            let available: Bool
            do { available = try await probe(min(8, remaining)) }
            catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                available = false
            }
            try Task.checkCancellation()
            guard whileNeeded() else { return false }
            guard now() < deadline else { throw timeoutError }
            let currentContext = context()
            if let previousContext, let currentContext, !previousContext.isEqual(currentContext) {
                successes = 0
                client.close()
            }
            successes = available ? successes + 1 : 0
            failures = available ? 0 : failures + 1
            previousContext = currentContext
            progress(successes)
            if successes >= requiredSuccesses {
                if let currentContext { success = (now(), currentContext) }
                return true
            }
            let pause = available ? interval : min(5, retryInterval * pow(2, Double(min(failures - 1, 3))))
            try await sleep(max(0, min(pause, deadline - now())))
        }
    }

    private var timeoutError: HushError {
        .message("等待\(conditionName)超时（\(Int(timeout)) 秒），未启动；\(failureHint)")
    }
}
