import XCTest
@testable import HushCore

final class LocalizationTests: XCTestCase {
    func testSystemLanguageResolutionAndEnglishFallback() {
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-TW", "en"]), .traditionalChinese)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-Hant-HK"]), .traditionalChinese)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.english.resolved(preferredLanguages: ["zh-CN"]), .english)
    }
    func testDynamicMessagesAndExistingHistory() {
        XCTAssertEqual(L10n.text("第 15 项", language: .english), "Item 15")
        XCTAssertEqual(L10n.text("已完成 · 2 项失败，请查看记录", language: .english), "Completed · 2 failed; see History")
        XCTAssertEqual(L10n.text("Surge · 等待基础网络就绪（1/2，最多 5 分钟）", language: .english), "Surge · Waiting for local network (1/2, up to 5 minutes)")
        XCTAssertEqual(L10n.text("网络检测已通过 · 已启动 · 已请求隐藏", language: .traditionalChinese), "網路檢查已通過 · 已啟動 · 已請求隱藏")
        XCTAssertEqual(L10n.text("网络 1.5 秒 / 启动 0.1 秒 / 总计 1.6 秒", language: .english), "Network 1.5 s / Launch 0.1 s / Total 1.6 s")
        XCTAssertEqual(L10n.text("My App", language: .traditionalChinese), "My App")
    }
    func testEveryCatalogEntryHasBothTranslations() {
        for key in L10n.keys {
            XCTAssertFalse(L10n.text(key, language: .english).isEmpty)
            XCTAssertFalse(L10n.text(key, language: .traditionalChinese).isEmpty)
            XCTAssertEqual(L10n.text(key, language: .simplifiedChinese), key)
        }
    }
    @MainActor func testPreferenceDefaultsAndPersistenceAreIsolated() {
        let name = "hush-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = AppPreferences(defaults: defaults)
        XCTAssertFalse(preferences.showDockIcon)
        XCTAssertTrue(preferences.showMenuBarIcon)
        XCTAssertEqual(preferences.language, .system)
        preferences.showDockIcon = true
        preferences.showMenuBarIcon = false
        preferences.language = .traditionalChinese
        let reloaded = AppPreferences(defaults: defaults)
        XCTAssertTrue(reloaded.showDockIcon)
        XCTAssertFalse(reloaded.showMenuBarIcon)
        XCTAssertEqual(reloaded.language, .traditionalChinese)
        defaults.set("invalid", forKey: "language")
        XCTAssertEqual(AppPreferences(defaults: defaults).language, .system)
    }
}
