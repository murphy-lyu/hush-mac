import AppKit
import SwiftUI
import Combine

@MainActor
final class SettingsWindow {
    enum Pane { case general, about }
    final class State: ObservableObject { @Published var pane: Pane = .general }
    private let state = State()
    private let login: LoginService
    private let preferences: AppPreferences
    private var window: NSWindow?
    private var languageObserver: AnyCancellable?
    private var paneObserver: AnyCancellable?
    init(login: LoginService, preferences: AppPreferences) {
        self.login = login
        self.preferences = preferences
        languageObserver = preferences.$language.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self else { return }
            self.updateTitle()
        }
        paneObserver = state.$pane.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            self?.updateTitle()
        }
    }
    private func updateTitle() {
        window?.title = L10n.text(state.pane == .general ? "通用" : "关于", language: preferences.effectiveLanguage)
    }
    func show(_ pane: Pane? = nil) {
        if let pane { state.pane = pane }
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
                                  styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.title = L10n.text(state.pane == .general ? "通用" : "关于", language: preferences.effectiveLanguage)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
            let host = NSHostingController(rootView: SettingsRootView(state: state, login: login, preferences: preferences))
            host.sizingOptions = []
            window.contentViewController = host
            window.setContentSize(NSSize(width: 500, height: 500))
            window.center()
            self.window = window
        }
        login.refresh()
        NSApp.activate(ignoringOtherApps: true)
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsRootView: View {
    @ObservedObject var state: SettingsWindow.State
    @ObservedObject var login: LoginService
    @ObservedObject var preferences: AppPreferences
    private func t(_ source: String) -> String { L10n.text(source, language: preferences.effectiveLanguage) }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(t(state.pane == .general ? "通用" : "关于")).font(HushTypography.font(size: 21, weight: .semibold))
                Spacer()
                tab(.general, title: t("通用"), symbol: "gearshape")
                tab(.about, title: t("关于"), symbol: "info.circle")
            }
            .frame(height: 56)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 26).padding(.top, 12).padding(.bottom, 14)
            .layoutPriority(1)
            Divider().opacity(0.35)
            Group {
                switch state.pane {
                case .general:
                    ScrollView { GeneralSettingsView(login: login, preferences: preferences) }
                case .about: AboutHushView(preferences: preferences)
                }
            }.frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .font(HushTypography.font(size: 13))
        .background { HushFrostedBackground() }
        .tint(.primary)
    }
    private func tab(_ pane: SettingsWindow.Pane, title: String, symbol: String) -> some View {
        Button { state.pane = pane } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 19))
                Text(title).font(HushTypography.font(size: 11))
            }.frame(width: 56, height: 40).padding(.vertical, 8)
                .background(state.pane == pane ? Color.primary.opacity(0.075) : .clear, in: RoundedRectangle(cornerRadius: 11))
                .contentShape(RoundedRectangle(cornerRadius: 11))
        }.buttonStyle(.plain).accessibilityAddTraits(state.pane == pane ? .isSelected : [])
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var login: LoginService
    @ObservedObject var preferences: AppPreferences
    private func t(_ source: String) -> String { L10n.text(source, language: preferences.effectiveLanguage) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            section(t("登录启动")) {
                VStack(spacing: 12) {
                    settingRow(t("登录时运行 Hush")) {
                        Toggle(t("登录时运行 Hush"), isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) }))
                            .labelsHidden().toggleStyle(.switch).controlSize(.small).disabled(!login.allowsSystemChanges)
                            .help(t("如应用已有登录启动设置，请先关闭，避免重复启动。"))
                    }
                    Text(t("登录后自动启动列表中已启用的应用。"))
                        .font(HushTypography.font(size: 11)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if login.needsApproval {
                        Text(t("请在系统设置中允许 Hush 登录时运行。"))
                            .font(HushTypography.font(size: 11)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                    settingRow(t("系统登录项")) {
                        Button(login.needsApproval ? t("前往系统设置…") : t("打开系统设置…")) { login.openSettings() }
                            .disabled(!login.allowsSystemChanges)
                    }
                }
            }
            section(t("外观")) {
                VStack(spacing: 12) {
                    settingRow(t("显示 Dock 图标")) {
                        Toggle(t("显示 Dock 图标"), isOn: $preferences.showDockIcon)
                            .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    }
                    Divider()
                    settingRow(t("显示菜单栏图标")) {
                        Toggle(t("显示菜单栏图标"), isOn: $preferences.showMenuBarIcon)
                            .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    }
                }
            }
            section(t("语言")) {
                settingRow(t("语言")) {
                    LanguagePopUp(value: $preferences.language, language: preferences.effectiveLanguage)
                        .frame(width: 172, height: 26)
                }
            }
            if !preferences.showDockIcon && !preferences.showMenuBarIcon {
                Text(t("可从 Finder 或 Spotlight 重新打开 Hush。")).font(HushTypography.font(size: 11)).foregroundStyle(.secondary)
            }
            if !login.allowsSystemChanges {
                Text(t("测试窗口 · 不修改系统登录项")).font(HushTypography.font(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.font(HushTypography.font(size: 13)).padding(.horizontal, 26).padding(.vertical, 20)
        .alert(t("无法更改登录启动设置"), isPresented: Binding(get: { login.error != nil }, set: { if !$0 { login.error = nil } })) {
            Button(t("好"), role: .cancel) { login.error = nil }
        } message: { Text(t(login.error ?? "")) }
    }
    private func settingRow<C: View>(_ title: String, @ViewBuilder control: () -> C) -> some View {
        HStack(spacing: 16) {
            Text(title).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            control().fixedSize()
        }.frame(minHeight: 24)
    }
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(HushTypography.font(size: 11, weight: .medium)).foregroundStyle(.secondary)
            content().padding(13).background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

@MainActor
private struct LanguagePopUp: NSViewRepresentable {
    @Binding var value: AppLanguage
    let language: AppLanguage
    func makeCoordinator() -> Coordinator { Coordinator(value: $value) }
    func makeNSView(context: Context) -> NSPopUpButton {
        let view = NSPopUpButton(frame: .zero, pullsDown: false)
        if let font = NSFont(name: "BerkeleyMono-Regular", size: view.font?.pointSize ?? NSFont.systemFontSize) {
            view.font = font
        }
        view.target = context.coordinator
        view.action = #selector(Coordinator.changed(_:))
        return view
    }
    func updateNSView(_ view: NSPopUpButton, context: Context) {
        context.coordinator.value = $value
        let titles = [L10n.text("跟随系统", language: language), "English", "简体中文", "繁體中文"]
        if view.itemArray.map(\.title) != titles {
            view.removeAllItems()
            for (index, title) in titles.enumerated() {
                view.addItem(withTitle: title)
                view.lastItem?.representedObject = AppLanguage.allCases[index].rawValue
            }
        }
        if view.indexOfSelectedItem != AppLanguage.allCases.firstIndex(of: value) {
            view.selectItem(at: AppLanguage.allCases.firstIndex(of: value)!)
        }
        view.setAccessibilityLabel(L10n.text("语言", language: language))
    }
    @MainActor
    final class Coordinator: NSObject {
        var value: Binding<AppLanguage>
        init(value: Binding<AppLanguage>) { self.value = value }
        @objc func changed(_ sender: NSPopUpButton) {
            guard let raw = sender.selectedItem?.representedObject as? String,
                  let language = AppLanguage(rawValue: raw), language != value.wrappedValue else { return }
            value.wrappedValue = language
        }
    }
}

private struct AboutHushView: View {
    @ObservedObject var preferences: AppPreferences
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—" }
    private var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—" }
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit().frame(width: 64, height: 64)
                .accessibilityLabel(L10n.text("Hush 应用图标", language: preferences.effectiveLanguage))
            Text("Hush").font(HushTypography.font(size: 24, weight: .semibold, design: .rounded))
            Text(L10n.text("管理登录后启动的应用", language: preferences.effectiveLanguage))
                .font(HushTypography.font(size: 11)).foregroundStyle(.secondary)
            Text(L10n.text("版本 \(version) · 构建 \(build)", language: preferences.effectiveLanguage)).font(HushTypography.font(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            Divider().frame(width: 160).padding(.vertical, 3)
            HStack(spacing: 10) {
                Link("Twitter / X", destination: URL(string: "https://x.com/yasashii_me")!).buttonStyle(.plain)
                Text("·").foregroundStyle(.tertiary)
                Link("GitHub", destination: URL(string: "https://github.com/murphy-lyu/hush-mac")!).buttonStyle(.plain)
            }.font(HushTypography.font(size: 12, design: .monospaced)).foregroundStyle(.primary)
            Text("@Murphy").font(HushTypography.font(size: 11, design: .monospaced)).foregroundStyle(.tertiary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
