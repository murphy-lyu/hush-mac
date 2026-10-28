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
        "无法完成操作": ["Could Not Complete Action", "無法完成操作"],
        "管理登录后启动的应用": ["Manage the apps that launch at login", "管理登入後啟動的應用程式"],
        "登录启动": ["Launch at Login", "登入啟動"],
        "如应用已有登录启动设置，请先关闭，避免重复启动。": ["Turn off each app’s own login launch setting to avoid duplicate launches.", "如應用程式已有登入啟動設定，請先關閉，避免重複啟動。"],
        "请在系统设置中允许 Hush 登录时运行。": ["Allow Hush to run at login in System Settings.", "請在系統設定中允許 Hush 登入時執行。"],
        "登录后自动启动列表中已启用的应用。": ["Automatically launch enabled apps in this list when you log in.", "登入後自動啟動列表中已啟用的應用程式。"],
        "网络工具优先启动，其余应用按列表顺序启动。": ["Network tools launch first; other apps follow the list order.", "網路工具優先啟動，其餘應用程式依列表順序啟動。"],
        "启动此应用前的等待时间，不含网络等待。网络工具优先，其余应用按列表顺序启动。": ["Wait before launching this app, in addition to any network wait. Network tools launch first; other apps follow the list order.", "啟動此應用程式前的等待時間，不含網路等待。網路工具優先，其餘應用程式依列表順序啟動。"],
        "停止后续启动，不会退出已启动的应用。": ["Stop launching the remaining apps. Apps already launched will keep running.", "停止啟動後續應用程式，已啟動的應用程式會繼續執行。"],
        "请在 Hush 的设置中开启登录启动，无需将 Hush 添加到列表。": ["Enable Hush at login in its settings instead of adding it to the app list.", "請在 Hush 的設定中開啟登入啟動，無須將 Hush 加入列表。"],
        "此位置的应用已更换，请从列表移除后重新添加。": ["The app at this location has changed. Remove it from the list and add it again.", "此位置的應用程式已更換，請從列表移除後重新加入。"],
        "不支持此配置版本，请更新 Hush 后重试。": ["This configuration version is not supported. Update Hush and try again.", "不支援此設定版本，請更新 Hush 後重試。"],
        "无法确认应用是否已启动，请检查应用后重试。": ["Could not confirm that the app launched. Check the app and try again.", "無法確認應用程式是否已啟動，請檢查應用程式後重試。"],
        "请在 Hush 的“设置 → 通用”中开启“登录时运行 Hush”。": ["To launch Hush at login, enable “Launch Hush at login” in Settings → General.", "請在 Hush 的「設定 → 一般」中開啟「登入時執行 Hush」。"],
        "无法更改登录启动设置": ["Could Not Change Login Setting", "無法更改登入啟動設定"],
        "打开系统设置…": ["Open System Settings…", "開啟系統設定…"],
        "前往系统设置…": ["Open System Settings…", "前往系統設定…"],
        "找不到应用，请从列表移除后重新添加。": ["App not found. Remove it from the list and add it again.", "找不到應用程式，請從列表移除後重新加入。"],
        "立即按此应用的设置测试启动，包含延迟和网络等待；未启用时也可测试。": ["Launch this app now using its delay and network settings, even if disabled.", "立即依此應用程式的設定測試啟動，包含延遲與網路等待；未啟用時也可測試。"],
        "启动时尝试隐藏窗口，不会最小化到 Dock；部分应用仍可能显示窗口。": ["Try to hide the app’s windows at launch, without minimizing to the Dock. Some apps may still show windows.", "啟動時嘗試隱藏視窗，不會縮小至 Dock；部分應用程式仍可能顯示視窗。"],
        "通过互联网连接检测后启动，不保证此应用的服务可用。最多等待 5 分钟，超时后跳过并记录失败。": ["Launch after the internet connection check passes. The app’s own service may still be unavailable. After 5 minutes, skip the app and record a failure.", "通過網際網路連線檢查後啟動，不保證此應用程式的服務可用。最多等待 5 分鐘，逾時後略過並記錄失敗。"],
        "等待 Wi-Fi 或有线网络连接就绪后启动，不要求互联网或代理可用。最多等待 5 分钟，超时后跳过并记录失败。": ["Wait for a local Wi-Fi or Ethernet connection, without checking internet or proxy access. After 5 minutes, skip the app and record a failure.", "等待 Wi-Fi 或有線網路連線就緒後啟動，不要求網際網路或代理可用。最多等待 5 分鐘，逾時後略過並記錄失敗。"],
        "操作": ["Actions", "操作"],
        "未启用": ["Disabled", "未啟用"],
        "登录启动和测试启动的结果会显示在这里。": ["Results from login and test launches appear here.", "登入啟動與測試啟動的結果會顯示在這裡。"],
        "立即按当前设置启动已启用的应用；已运行的应用会跳过。网络工具优先启动。": ["Launch enabled apps now using your settings. Apps already running are skipped; network tools launch first.", "立即依目前設定啟動已啟用的應用程式；略過已執行的應用程式，網路工具優先啟動。"],
        "测试启动": ["Test Launch", "測試啟動"],
        "添加应用…": ["Add Apps…", "加入應用程式…"],
        "添加登录后要启动的应用，再设置启动方式和顺序。": ["Add the apps you want to launch at login, then set how and when they open.", "加入登入後要啟動的應用程式，再設定啟動方式與順序。"],
        "还没有添加应用": ["No startup apps yet", "尚未加入應用程式"],
        "显示菜单栏图标": ["Show menu bar icon", "顯示選單列圖示"],
        "可从 Finder 或 Spotlight 重新打开 Hush。": ["Reopen Hush from Finder or Spotlight.", "可從 Finder 或 Spotlight 重新開啟 Hush。"],
        "版本 %@ · 构建 %@": ["Version %@ · Build %@", "版本 %@ · 建置 %@"],
        "停止本次启动": ["Stop Launching", "停止後續啟動"],
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
        "好": ["OK", "好"],
        "测试窗口 · 不修改系统登录项": ["Test window · Login items are protected", "測試視窗 · 不修改系統登入項目"],
        "Hush 应用图标": ["Hush app icon", "Hush 應用程式圖示"],
        "外观": ["Appearance", "外觀"],
        "显示 Dock 图标": ["Show Dock icon", "顯示 Dock 圖示"],
        "语言": ["Language", "語言"],
        "跟随系统": ["Follow System", "跟隨系統"],
        "启动应用": ["Startup Apps", "啟動應用程式"],
        "启动记录": ["History", "啟動記錄"],
        "清空记录": ["Clear History", "清除記錄"],
        "停止": ["Stop", "停止"],
        "添加应用": ["Add Apps", "加入應用程式"],
        "已启用": ["Enabled", "已啟用"],
        "等待网络": ["Network Wait", "等待網路"],
        "隐藏启动": ["Launch Hidden", "隱藏啟動"],
        "也可以把应用拖到这里": ["Or drag apps here", "也可以將應用程式拖到這裡"],
        "应用": ["Application", "應用程式"],
        "联网后": ["Network", "等網路"],
        "隐藏": ["Hide", "隱藏"],
        "延迟": ["Delay", "延遲"],
        "还没有启动记录": ["No launch history yet", "尚無啟動記錄"],
        "添加启动应用": ["Add Startup Apps", "加入啟動應用程式"],
        "添加": ["Add", "加入"],
        "请选择有效的 macOS 应用（.app）。": ["Choose a valid macOS application (.app).", "請選擇有效的 macOS 應用程式（.app）。"],
        "启用 %@": ["Enable %@", "啟用 %@"],
        "正在处理…": ["Processing…", "正在處理…"],
        "第 %d 项": ["Item %d", "第 %d 項"],
        "等待网络可用后启动 %@": ["Wait for network before launching %@", "等待網路可用後啟動 %@"],
        "隐藏启动 %@": ["Launch %@ hidden", "隱藏啟動 %@"],
        "%@ 的更多操作": ["More actions for %@", "%@ 的更多操作"],
        "上移": ["Move Up", "上移"],
        "下移": ["Move Down", "下移"],
        "在访达中显示": ["Show in Finder", "在 Finder 中顯示"],
        "从列表移除": ["Remove from List", "從列表移除"],
        "延迟时间": ["Launch delay", "延遲時間"],
        "无延迟": ["None", "無延遲"],
        "%d 秒": ["%d s", "%d 秒"],
        "准备就绪": ["Ready", "準備就緒"],
        "没有已启用的应用": ["No enabled apps", "沒有已啟用的應用程式"],
        "已在运行，跳过": ["Already running; skipped", "已在執行，略過"],
        "%@ · 等待 %d 秒": ["%@ · Waiting %d s", "%@ · 等待 %d 秒"],
        "基础网络就绪": ["local network", "基礎網路就緒"],
        "网络可用": ["internet access", "網路可用"],
        "%@ · 等待%@（%d/%d，最多 5 分钟）": ["%@ · Waiting for %@ (%d/%d, up to 5 minutes)", "%@ · 等待%@（%d/%d，最多 5 分鐘）"],
        "正在启动 %@": ["Launching %@", "正在啟動 %@"],
        "基础网络检测已通过": ["Local network check passed", "區域網路連線檢查已通過"],
        "网络检测已通过": ["Internet check passed", "網路連線檢查已通過"],
        "已停止；已启动的应用会继续运行": ["Stopped; launched apps will keep running", "已停止；已啟動的應用程式會繼續執行"],
        "本次启动已完成": ["Launch complete", "本次啟動已完成"],
        "已完成 · %d 项失败，请查看记录": ["Completed · %d failed; see History", "已完成 · %d 項失敗，請查看記錄"],
        "正在停止后续启动…": ["Stopping…", "正在停止後續啟動…"],
        "网络 %.1f 秒 / 启动 %.1f 秒 / 总计 %.1f 秒": ["Network wait %.1f s / Launch %.1f s / Total %.1f s", "等待網路 %.1f 秒 / 啟動 %.1f 秒 / 總計 %.1f 秒"],
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
        // This error can appear in launch history saved by earlier versions.
        "系统未返回应用进程。": ["Could not confirm that the app launched. Check the app and try again.", "無法確認應用程式是否已啟動，請檢查應用程式後重試。"],
        "已隐藏启动": ["Launched hidden", "已隱藏啟動"],
        "已启动": ["Launched", "已啟動"],
        "已请求隐藏": ["Hidden launch requested", "已請求隱藏"],
        "已正常启动": ["Launched", "已啟動"],
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
