import AppKit

@MainActor
final class SystemLauncher: ApplicationLaunching {
    func resolvedURL(_ item: StartupItem) -> URL {
        if let bookmark = item.bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting],
                                  relativeTo: nil, bookmarkDataIsStale: &stale) { return url }
        }
        return URL(fileURLWithPath: item.path)
    }

    func isRunning(_ item: StartupItem) -> Bool {
        let target = resolvedURL(item).resolvingSymlinksInPath().standardizedFileURL
        return NSWorkspace.shared.runningApplications.contains {
            if let id = item.bundleIdentifier, $0.bundleIdentifier == id { return true }
            return $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL == target
        }
    }

    func launch(_ item: StartupItem) async throws -> String {
        let url = resolvedURL(item)
        guard FileManager.default.fileExists(atPath: url.path), let bundle = Bundle(url: url),
              bundle.executableURL != nil else {
            throw HushError.message("找不到应用，请移除后重新添加。")
        }
        guard bundle.bundleIdentifier != Bundle.main.bundleIdentifier else {
            throw HushError.message("不能把 Hush 添加到自己的启动列表。")
        }
        if let expected = item.bundleIdentifier, bundle.bundleIdentifier != expected {
            throw HushError.message("此路径的应用已发生变化，请重新添加。")
        }
        let request = LaunchRequest()
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                request.continuation = continuation
                let options = NSWorkspace.OpenConfiguration()
                options.activates = !item.hidden
                options.hides = item.hidden
                options.addsToRecentItems = false
                NSWorkspace.shared.openApplication(at: url, configuration: options) { app, error in
                    Task { @MainActor in
                        guard request.continuation != nil else { return }
                        if let error { request.finish(.failure(error)); return }
                        guard let app else {
                            request.finish(.failure(HushError.message("系统未返回应用进程。"))); return
                        }
                        // Never hide an application the user has brought to the front.
                        if item.hidden && !app.isActive { _ = app.hide() }
                        let detail = item.hidden
                            ? (app.isHidden ? "已隐藏启动" : "已启动 · 已请求隐藏")
                            : "已正常启动"
                        request.finish(.success(detail))
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
                    request.finish(.failure(HushError.message("等待启动超时，应用仍可能稍后打开。")))
                }
            }
        }, onCancel: {
            Task { @MainActor in request.finish(.failure(CancellationError())) }
        })
    }
}

@MainActor
private final class LaunchRequest {
    var continuation: CheckedContinuation<String, Error>?
    func finish(_ result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
