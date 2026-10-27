import Foundation

/// A successful HTTPS response checks DNS, TLS and the system's configured proxy path.
/// It does not certify that every application-specific service is reachable.
@MainActor
enum HTTPSNetworkProbe {
    static let url = URL(string: "https://www.apple.com/library/test/success.html")!

    static func check(timeout: TimeInterval) async throws -> Bool {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: timeout)
        request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        return isSuccessful(data: data, response: response)
    }

    static func isSuccessful(data: Data, response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200, http.url == url,
              let body = String(data: data, encoding: .utf8) else { return false }
        return body.range(of: "<title>Success</title>", options: .caseInsensitive) != nil
    }
}

@MainActor
final class NetworkReadiness {
    private let probe: (TimeInterval) async throws -> Bool
    private let sleep: (TimeInterval) async throws -> Void
    private let now: () -> TimeInterval
    private let timeout: TimeInterval
    private let interval: TimeInterval
    private let requiredSuccesses: Int
    private let conditionName: String
    private let failureHint: String

    init(timeout: TimeInterval = 300, interval: TimeInterval = 5, requiredSuccesses: Int = 3,
         conditionName: String = "网络可用", failureHint: String = "请检查网络或代理后重试。",
         probe: @escaping (TimeInterval) async throws -> Bool = HTTPSNetworkProbe.check,
         sleep: @escaping (TimeInterval) async throws -> Void = {
             try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000))
         }, now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        precondition(timeout > 0 && interval > 0 && requiredSuccesses > 0)
        self.conditionName = conditionName
        self.failureHint = failureHint
        self.timeout = timeout
        self.interval = interval
        self.requiredSuccesses = requiredSuccesses
        self.probe = probe
        self.sleep = sleep
        self.now = now
    }

    /// Returns false if the user opened the application while waiting.
    func waitUntilReady(whileNeeded: () -> Bool, progress: (Int) -> Void) async throws -> Bool {
        let deadline = now() + timeout
        var successes = 0
        while true {
            try Task.checkCancellation()
            guard whileNeeded() else { return false }
            let remaining = deadline - now()
            guard remaining > 0 else { throw timeoutError }
            progress(successes)
            let available: Bool
            do {
                available = try await probe(min(8, remaining))
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                available = false
            }
            try Task.checkCancellation()
            guard whileNeeded() else { return false }
            guard now() < deadline else { throw timeoutError }
            successes = available ? successes + 1 : 0
            progress(successes)
            if successes >= requiredSuccesses { return true }
            try await sleep(max(0, min(interval, deadline - now())))
        }
    }

    private var timeoutError: HushError {
        .message("等待\(conditionName)超时（\(Int(timeout)) 秒），未启动；\(failureHint)")
    }
}
