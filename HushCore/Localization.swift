import Foundation

enum AppLanguage: String, CaseIterable {
    case system, english, simplifiedChinese, traditionalChinese
    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        for preferred in preferredLanguages {
            let tag = preferred.lowercased().replacingOccurrences(of: "_", with: "-")
            if tag.hasPrefix("en") { return .english }
            if tag.hasPrefix("zh") {
                return tag.contains("hant") || tag.contains("tw") || tag.contains("hk") || tag.contains("mo")
                    ? .traditionalChinese : .simplifiedChinese
            }
        }
        return .english
    }
}

/// Original messages remain stable on disk. Translate at presentation time so
/// existing history, live progress and errors follow language changes as well.
enum L10n {
    private static let catalog: [String: [String]] = [
        "显示菜单栏图标": ["Show menu bar icon", "顯示選單列圖示"],
        "可从 Finder 或 Spotlight 重新打开 Hush。": ["Reopen Hush from Finder or Spotlight.", "可從 Finder 或 Spotlight 重新開啟 Hush。"],
        "版本 %@ · 构建 %@": ["Version %@ · Build %@", "版本 %@ · 建置 %@"],
        "停止本次启动": ["Stop This Launch", "停止本次啟動"],
        "设置": ["Settings", "設定"],
        "设置…": ["Settings", "設定"],
        "通用": ["General", "一般"],
        "关于": ["About", "關於"],
        "关于 Hush": ["About Hush", "關於 Hush"],
        "打开 Hush": ["Open Hush", "開啟 Hush"],
        "退出 Hush": ["Quit Hush", "結束 Hush"],
        "启动已启用的应用": ["Launch Enabled Apps", "啟動已啟用的應用程式"],
        "停止后续启动": ["Stop Launching", "停止後續啟動"],
        "启动": ["Startup", "啟動"],
        "登录时运行 Hush": ["Launch Hush at login", "登入時執行 Hush"],
        "系统登录项": ["System login items", "系統登入項目"],
        "前往允许…": ["Allow in Settings…", "前往允許…"],
        "打开设置…": ["Open Settings…", "開啟設定…"],
        "无法更新登录启动": ["Unable to update login item", "無法更新登入啟動"],
        "好": ["OK", "好"],
        "需要处理": ["Action Required", "需要處理"],
        "测试窗口 · 不修改系统登录项": ["Test window · Login items are protected", "測試視窗 · 不修改系統登入項目"],
        "Hush 应用图标": ["Hush app icon", "Hush 應用程式圖示"],
        "外观": ["Appearance", "外觀"],
        "显示 Dock 图标": ["Show Dock icon", "顯示 Dock 圖示"],
        "语言": ["Language", "語言"],
        "跟随系统": ["Follow System", "跟隨系統"],
        "启动应用": ["Applications", "啟動應用程式"],
        "启动记录": ["History", "啟動記錄"],
        "清空记录": ["Clear History", "清除記錄"],
        "停止": ["Stop", "停止"],
        "测试全部": ["Test All", "測試全部"],
        "添加应用": ["Add Apps", "加入應用程式"],
        "已启用": ["Enabled", "已啟用"],
        "等待网络": ["Wait for Network", "等待網路"],
        "隐藏启动": ["Launch Hidden", "隱藏啟動"],
        "按延迟和网络条件启动已启用应用；已运行的应用会跳过": ["Launch enabled apps using their delay and network settings; skip apps already running.", "依延遲與網路條件啟動已啟用的應用程式；略過已執行的應用程式。"],
        "从一个安静的早晨开始": ["Start with a quiet morning", "從一個安靜的早晨開始"],
        "添加登录后需要的应用，设置隐藏、延迟、网络等待与启动顺序。": ["Add your apps and choose their launch order, delay and network requirements.", "加入登入後需要的應用程式，設定隱藏、延遲、網路等待與啟動順序。"],
        "选择应用…": ["Choose Apps…", "選擇應用程式…"],
        "也可以把应用拖到这里": ["Or drag apps here", "也可以將應用程式拖到這裡"],
        "应用": ["Application", "應用程式"],
        "联网后": ["Network", "連線後"],
        "隐藏": ["Hidden", "隱藏"],
        "延迟": ["Delay", "延遲"],
        "顺序 / 测试": ["Order / Test", "順序 / 測試"],
        "还没有启动记录": ["No launch history yet", "尚無啟動記錄"],
        "测试启动后，可以在这里查看结果。": ["Launch results will appear here.", "測試啟動後，可在這裡查看結果。"],
        "添加启动应用": ["Add Startup Apps", "加入啟動應用程式"],
        "添加": ["Add", "加入"],
        "请选择有效的 macOS 应用（.app）。": ["Choose a valid macOS application (.app).", "請選擇有效的 macOS 應用程式（.app）。"],
        "Hush 的登录启动请在设置中开启。": ["Enable Hush at login in Settings.", "請在設定中開啟 Hush 登入啟動。"],
        "启用 %@": ["Enable %@", "啟用 %@"],
        "正在处理…": ["Processing…", "正在處理…"],
        "第 %d 项": ["Item %d", "第 %d 項"],
        "已暂停": ["Paused", "已暫停"],
        "等待网络可用后启动 %@": ["Wait for network before launching %@", "等待網路可用後啟動 %@"],
        "隐藏启动 %@": ["Launch %@ hidden", "隱藏啟動 %@"],
        "%@ 的更多操作": ["More actions for %@", "%@ 的更多操作"],
        "Wi-Fi 或有线取得有效 IP 和网关后即可启动，不检查外网或代理。未就绪时退避重试，最多等待 5 分钟。": ["Wait for a valid Wi-Fi or Ethernet address and gateway. No internet or proxy check. Retry for up to 5 minutes.", "Wi-Fi 或有線網路取得有效 IP 與閘道後即可啟動，不檢查外網或代理。未就緒時退避重試，最多等待 5 分鐘。"],
        "首次间隔 0.5 秒确认 2 次 HTTPS 成功；同一轮 15 秒内且网络状态未变时复用结果。失败退避重试，最多等待 5 分钟。不保证各应用服务均可达。": ["Confirm HTTPS twice, 0.5 seconds apart. Reuse results for 15 seconds in the same run if network settings are unchanged. Retry for up to 5 minutes. App services may still be unavailable.", "首次間隔 0.5 秒確認 2 次 HTTPS 成功；同一輪 15 秒內且網路狀態未變時重用結果。失敗退避重試，最多等待 5 分鐘。不保證各應用程式服務皆可連線。"],
        "请求隐藏启动，效果取决于应用；不会最小化到 Dock": ["Request a hidden launch; the app controls the result. This does not minimize it to the Dock.", "請求隱藏啟動，效果取決於應用程式；不會縮小至 Dock。"],
        "上移": ["Move Up", "上移"],
        "下移": ["Move Down", "下移"],
        "测试此应用（含延迟与网络等待）": ["Test this app, including delay and network wait", "測試此應用程式（含延遲與網路等待）"],
        "在访达中显示": ["Show in Finder", "在 Finder 中顯示"],
        "从列表移除": ["Remove from List", "從列表移除"],
        "延迟时间": ["Launch delay", "延遲時間"],
        "无延迟": ["None", "無延遲"],
        "%d 秒": ["%d s", "%d 秒"],
        "应用路径不可用，请通过更多操作移除后重新添加": ["App path is unavailable. Remove it and add it again.", "應用程式路徑無法使用，請移除後重新加入。"],
        "准备就绪": ["Ready", "準備就緒"],
        "没有已启用的应用": ["No enabled apps", "沒有已啟用的應用程式"],
        "已在运行，跳过": ["Already running; skipped", "已在執行，略過"],
        "%@ · 等待 %d 秒": ["%@ · Waiting %d s", "%@ · 等待 %d 秒"],
        "基础网络就绪": ["local network", "基礎網路就緒"],
        "网络可用": ["internet access", "網路可用"],
        "%@ · 等待%@（%d/%d，最多 5 分钟）": ["%@ · Waiting for %@ (%d/%d, up to 5 minutes)", "%@ · 等待%@（%d/%d，最多 5 分鐘）"],
        "正在启动 %@": ["Launching %@", "正在啟動 %@"],
        "基础网络检测已通过": ["Local network ready", "基礎網路檢查已通過"],
        "网络检测已通过": ["Internet ready", "網路檢查已通過"],
        "已停止；已启动的应用会继续运行": ["Stopped; launched apps will keep running", "已停止；已啟動的應用程式會繼續執行"],
        "本次启动已完成": ["Launch complete", "本次啟動已完成"],
        "已完成 · %d 项失败，请查看记录": ["Completed · %d failed; see History", "已完成 · %d 項失敗，請查看記錄"],
        "正在停止后续启动…": ["Stopping…", "正在停止後續啟動…"],
        "网络 %.1f 秒 / 启动 %.1f 秒 / 总计 %.1f 秒": ["Network %.1f s / Launch %.1f s / Total %.1f s", "網路 %.1f 秒 / 啟動 %.1f 秒 / 總計 %.1f 秒"],
        "启动记录未能保存：%@": ["Could not save history: %@", "無法儲存啟動記錄：%@"],
        "无法更新登录启动：%@": ["Could not update login item: %@", "無法更新登入啟動：%@"],
        "无法读取启动列表：%@": ["Could not load startup apps: %@", "無法讀取啟動列表：%@"],
        "保存失败：%@": ["Could not save: %@", "儲存失敗：%@"],
        "%@ 已在启动列表中。": ["%@ is already in the list.", "%@ 已在啟動列表中。"],
        "配置读取失败，已暂停编辑，避免覆盖原文件。请修复配置后重新打开 Hush。": ["Editing is paused because the configuration could not be read. Repair it and reopen Hush. The original file is preserved.", "設定讀取失敗，已暫停編輯以避免覆寫原始檔案。請修復設定後重新開啟 Hush。"],
        "配置版本较新，请更新 Hush 后重试。": ["This configuration requires a newer version of Hush.", "設定版本較新，請更新 Hush 後重試。"],
        "配置内容无效，原文件已保留。": ["Invalid configuration. The original file is preserved.", "設定內容無效，已保留原始檔案。"],
        "找不到应用，请移除后重新添加。": ["App not found. Remove it and add it again.", "找不到應用程式，請移除後重新加入。"],
        "不能把 Hush 添加到自己的启动列表。": ["Hush cannot be added to its own startup list.", "無法將 Hush 加入自己的啟動列表。"],
        "此路径的应用已发生变化，请重新添加。": ["The app at this path has changed. Add it again.", "此路徑的應用程式已變更，請重新加入。"],
        "系统未返回应用进程。": ["The system did not return an app process.", "系統未傳回應用程式程序。"],
        "已隐藏启动": ["Launched hidden", "已隱藏啟動"],
        "已启动": ["Launched", "已啟動"],
        "已请求隐藏": ["Hidden launch requested", "已請求隱藏"],
        "已正常启动": ["Launched", "已正常啟動"],
        "等待启动超时，应用仍可能稍后打开。": ["Launch timed out. The app may still open later.", "等待啟動逾時，應用程式仍可能稍後開啟。"],
        "等待%@超时（%d 秒），未启动；%@": ["Timed out waiting for %@ (%d s); app not launched. %@", "等待%@逾時（%d 秒），未啟動；%@"],
        "请检查网络或代理后重试。": ["Check your network or proxy and try again.", "請檢查網路或代理後重試。"],
        "请检查 Wi-Fi 或有线连接是否取得 IP 和网关。": ["Check that Wi-Fi or Ethernet has an IP address and gateway.", "請檢查 Wi-Fi 或有線連線是否取得 IP 與閘道。"],
    ]
    static var keys: [String] { Array(catalog.keys) }
    private static let placeholder = try! NSRegularExpression(pattern: "%@|%d|%\\.1f")
    private static let patterns: [(String, NSRegularExpression)] = catalog.keys.filter { $0.contains("%") }.sorted { $0.count > $1.count }.map { key in
        let parts = placeholder.matches(in: key, range: NSRange(key.startIndex..., in: key))
        var expression = "^"
        var cursor = key.startIndex
        for part in parts {
            let range = Range(part.range, in: key)!
            expression += NSRegularExpression.escapedPattern(for: String(key[cursor..<range.lowerBound]))
            expression += key[range] == "%@" ? "(.+?)" : "([0-9]+(?:\\.[0-9]+)?)"
            cursor = range.upperBound
        }
        expression += NSRegularExpression.escapedPattern(for: String(key[cursor...])) + "$"
        return (key, try! NSRegularExpression(pattern: expression))
    }
    static func text(_ source: String, language: AppLanguage) -> String {
        let language = language.resolved()
        if language == .simplifiedChinese { return source }
        if let translations = catalog[source] { return translations[language == .english ? 0 : 1] }
        for (key, pattern) in patterns {
            guard let match = pattern.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)) else { continue }
            let arguments = (1..<match.numberOfRanges).map { text(String(source[Range(match.range(at: $0), in: source)!]), language: language) }
            let template = catalog[key]![language == .english ? 0 : 1]
            var result = "", cursor = template.startIndex
            for (index, part) in placeholder.matches(in: template, range: NSRange(template.startIndex..., in: template)).enumerated() {
                let range = Range(part.range, in: template)!
                result += template[cursor..<range.lowerBound] + arguments[index]
                cursor = range.upperBound
            }
            return result + template[cursor...]
        }
        if source.contains(" · ") { return source.components(separatedBy: " · ").map { text($0, language: language) }.joined(separator: " · ") }
        return source
    }
}
