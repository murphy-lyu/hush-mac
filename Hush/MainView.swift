import SwiftUI
import AppKit
import UniformTypeIdentifiers

private let hushAccent = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(white: 0.86, alpha: 1) : NSColor(white: 0.22, alpha: 1)
})

struct MainView: View {
    @ObservedObject var store: StartupStore
    @ObservedObject var runner: LaunchRunner
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var login: LoginService
    var openSettings: () -> Void
    @State private var showingHistory = false
    @State private var dropTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(alignment: .leading, spacing: 18) {
                header
                if !showingHistory { overview }
                if showingHistory { history } else { applications }
                footer
            }
            .padding(.horizontal, 22).padding(.top, 34).padding(.bottom, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .font(HushTypography.font(size: 13))
        .background { HushFrostedBackground() }
        .environment(\.hushLanguage, preferences.effectiveLanguage)
        .tint(hushAccent)
        .frame(minWidth: 860, minHeight: 580)
        .alert(t("需要处理"), isPresented: Binding(
            get: { store.error != nil },
            set: { if !$0 { store.error = nil } }
        )) {
            Button(t("好"), role: .cancel) { store.error = nil }
        } message: { Text(t(store.error ?? "")) }
    }

    private func t(_ source: String) -> String { L10n.text(source, language: preferences.effectiveLanguage) }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack")
                    .font(.system(size: 25)).foregroundStyle(hushAccent)
                Text("Hush").font(HushTypography.font(size: 23, weight: .semibold, design: .rounded))
            }.padding(.horizontal, 12)
            VStack(spacing: 5) {
                navigationItem(t("启动应用"), symbol: "square.stack.3d.up", selected: !showingHistory) { showingHistory = false }
                navigationItem(t("启动记录"), symbol: "clock.arrow.circlepath", selected: showingHistory) { showingHistory = true }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                Button(action: openSettings) {
                    HStack(spacing: 9) {
                        Image(systemName: "gearshape")
                        Text(t("设置")).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    }
                        .font(HushTypography.font(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                    .keyboardShortcut(",", modifiers: .command)
                if !login.allowsSystemChanges {
                    Text(t("测试窗口 · 不修改系统登录项")).font(HushTypography.font(size: 10)).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 10)
        }
        .padding(.horizontal, 12).padding(.top, 42).padding(.bottom, 22)
        .frame(width: 176)

    }

    private func navigationItem(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(HushTypography.font(size: 13, weight: selected ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 13).padding(.vertical, 12)
                .background(selected ? hushAccent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 11))
                .contentShape(RoundedRectangle(cornerRadius: 11))
                .foregroundStyle(selected ? hushAccent : Color.primary)
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text(showingHistory ? t("启动记录") : t("启动应用"))
                .font(HushTypography.font(size: 26, weight: .bold))
            Spacer(minLength: 8)
            if showingHistory {
                Button(t("清空记录")) { runner.clearHistory() }
                    .modifier(HushActionStyle()).disabled(runner.records.isEmpty)
            } else {
                Button { if runner.isRunning { runner.cancel() } else { runner.start(store.items) } } label: {
                    Label(runner.isRunning ? t("停止") : t("测试全部"), systemImage: runner.isRunning ? "stop.fill" : "play.fill")
                }
                .modifier(HushActionStyle())
                .disabled(!runner.isRunning && (store.loadFailed || !store.items.contains(where: \.enabled)))
                .help(t("按延迟和网络条件启动已启用应用；已运行的应用会跳过"))
                Button(action: addApplications) { Label(t("添加应用"), systemImage: "plus") }
                    .modifier(HushActionStyle(prominent: true))
                    .disabled(runner.isRunning || store.loadFailed)
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
    }

    private var overview: some View {
        HStack(spacing: 14) {
            summary(t("已启用"), count: store.items.filter(\.enabled).count, symbol: "power", color: hushAccent)
            summary(t("等待网络"), count: store.items.filter { $0.enabled && $0.waitForNetwork }.count, symbol: "wifi", color: hushAccent)
            summary(t("隐藏启动"), count: store.items.filter { $0.enabled && $0.hidden }.count, symbol: "eye.slash", color: hushAccent)
        }
    }

    private func summary(_ title: String, count: Int, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .medium))
                .foregroundStyle(color).frame(width: 30, height: 30)
                .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(HushTypography.font(size: 11)).foregroundStyle(.secondary)
                Text("\(count)").font(HushTypography.font(size: 20, weight: .semibold)).monospacedDigit()
            }
            Spacer(minLength: 0)
        }.padding(13).frame(maxWidth: .infinity).modifier(HushSurface())
    }

    private var applications: some View {
        VStack(spacing: 14) {
            if store.items.isEmpty {
                VStack(spacing: 13) {
                    Image(systemName: "sun.horizon")
                        .font(.system(size: 40, weight: .ultraLight)).foregroundStyle(hushAccent)
                    Text(t("从一个安静的早晨开始"))
                        .font(HushTypography.font(size: 18, weight: .medium))
                    Text(t("添加登录后需要的应用，设置隐藏、延迟、网络等待与启动顺序。"))
                        .font(HushTypography.font(size: 13)).foregroundStyle(.secondary)
                    Button(t("选择应用…"), action: addApplications)
                        .padding(.top, 4).disabled(store.loadFailed)
                    Text(t("也可以把应用拖到这里"))
                        .font(HushTypography.font(size: 11)).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(dropTargeted ? hushAccent : Color.primary.opacity(0.07), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text(t("应用")).frame(maxWidth: .infinity, alignment: .leading)
                        Text(t("联网后")).frame(width: 52)
                        Text(t("隐藏")).frame(width: 44)
                        Text(t("延迟")).frame(width: 90)
                        Text(t("顺序 / 测试")).frame(width: 120)
                    }
                    .font(HushTypography.font(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    Divider().opacity(0.5)
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                                AppRow(item: item, index: index, count: store.items.count,
                                       running: runner.isRunning, active: runner.currentID == item.id,
                                       update: { change in store.update(item.id, change) },
                                       move: { store.move(item.id, by: $0) },
                                       test: { runner.start([item], test: true) },
                                       remove: { store.remove(item.id) })
                                if index < store.items.count - 1 { Divider().padding(.leading, 63).opacity(0.5) }
                            }
                        }
                    }
                }
                .modifier(HushSurface())
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(dropTargeted ? hushAccent : .clear))
            }

        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $dropTargeted) { providers in
            guard !runner.isRunning && !store.loadFailed else { return false }
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in addApplication(url) }
                }
            }
            return true
        }
    }

    private var history: some View {
        Group {
            if runner.records.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock").font(.system(size: 34, weight: .light)).foregroundStyle(.tertiary)
                    Text(t("还没有启动记录")).font(HushTypography.font(size: 15, weight: .medium))
                    Text(t("测试启动后，可以在这里查看结果。"))
                        .font(HushTypography.font(size: 12)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(runner.records) { record in
                            HStack(spacing: 12) {
                                Image(systemName: record.failed ? "exclamationmark.circle" : "checkmark.circle")
                                    .foregroundStyle(record.failed ? Color.orange : hushAccent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.name).font(HushTypography.font(size: 13, weight: .medium))
                                    Text(t(record.detail)).font(HushTypography.font(size: 11)).foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                                Spacer()
                                Text(record.date, format: .dateTime.month().day().hour().minute().second())
                                    .font(HushTypography.font(size: 11)).foregroundStyle(.tertiary)
                            }.padding(15)
                            Divider().padding(.leading, 43).opacity(0.5)
                        }
                    }
                }.modifier(HushSurface())
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 9) {
            if runner.isRunning { ProgressView().controlSize(.small) }
            else { Circle().fill(runner.historyWarning == nil ? Color.green : Color.orange).frame(width: 6, height: 6) }
            Text(t(runner.historyWarning ?? runner.status)).font(HushTypography.font(size: 11)).foregroundStyle(.secondary)
                .lineLimit(1).help(t(runner.historyWarning ?? runner.status))
            Spacer(minLength: 0)
        }
    }

    private func addApplications() {
        let panel = NSOpenPanel()
        panel.title = t("添加启动应用")
        panel.prompt = t("添加")
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK { for url in panel.urls { addApplication(url) } }
    }

    private func addApplication(_ input: URL) {
        guard !runner.isRunning else { return }
        let url = input.resolvingSymlinksInPath().standardizedFileURL
        guard url.pathExtension.lowercased() == "app", let bundle = Bundle(url: url), bundle.executableURL != nil else {
            store.error = t("请选择有效的 macOS 应用（.app）。"); return
        }
        guard bundle.bundleIdentifier != Bundle.main.bundleIdentifier else {
            store.error = t("Hush 的登录启动请在设置中开启。"); return
        }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        store.add(StartupItem(name: name, path: url.path, bundleIdentifier: bundle.bundleIdentifier, bookmark: bookmark))
    }
}

private struct AppRow: View {
    @Environment(\.hushLanguage) private var language
    private func t(_ source: String) -> String { L10n.text(source, language: language) }
    let item: StartupItem
    let index: Int
    let count: Int
    let running: Bool
    let active: Bool
    let update: ((inout StartupItem) -> Void) -> Void
    let move: (Int) -> Void
    let test: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle(t("启用 \(item.name)"), isOn: Binding(get: { item.enabled }, set: { value in update { $0.enabled = value } }))
                .labelsHidden().toggleStyle(.checkbox).disabled(running)
            ApplicationIcon(path: item.path)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(HushTypography.font(size: 13, weight: .medium)).lineLimit(1)
                Text(active ? t("正在处理…") : (item.enabled ? t("第 \(index + 1) 项") : t("已暂停")))
                    .font(HushTypography.font(size: 10)).foregroundStyle(active ? hushAccent : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).help(item.path)
            Toggle(t("等待网络可用后启动 \(item.name)"), isOn: Binding(get: { item.waitForNetwork }, set: { value in update { $0.waitForNetwork = value } }))
                .labelsHidden().toggleStyle(.checkbox).frame(width: 52).disabled(running)
                .help(item.providesNetwork ? t("Wi-Fi 或有线取得有效 IP 和网关后即可启动，不检查外网或代理。未就绪时退避重试，最多等待 5 分钟。") : t("首次间隔 0.5 秒确认 2 次 HTTPS 成功；同一轮 15 秒内且网络状态未变时复用结果。失败退避重试，最多等待 5 分钟。不保证各应用服务均可达。"))
            Toggle(t("隐藏启动 \(item.name)"), isOn: Binding(get: { item.hidden }, set: { value in update { $0.hidden = value } }))
                .labelsHidden().toggleStyle(.checkbox).frame(width: 44).disabled(running)
                .help(t("请求隐藏启动，效果取决于应用；不会最小化到 Dock"))
            DelayPopUp(value: Binding(get: { item.delay }, set: { value in update { $0.delay = value } }),
                       enabled: !running)
                .frame(width: 90, height: 24)
            HStack(spacing: 3) {
                rowButton("chevron.up", help: t("上移"), disabled: running || index == 0) { move(-1) }
                rowButton("chevron.down", help: t("下移"), disabled: running || index == count - 1) { move(1) }
                rowButton("play", help: t("测试此应用（含延迟与网络等待）"), disabled: running, action: test)
                Menu {
                    Button(t("在访达中显示")) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)]) }
                    Divider()
                    Button(t("从列表移除"), role: .destructive, action: remove).disabled(running)
                } label: { Image(systemName: "ellipsis").frame(width: 22, height: 26) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel(t("\(item.name) 的更多操作"))
            }.frame(width: 120)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(active ? hushAccent.opacity(0.05) : .clear)
        .opacity(item.enabled ? 1 : 0.60)
    }

    private func rowButton(_ symbol: String, help: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .medium)).frame(width: 24, height: 26)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(.secondary).disabled(disabled).help(t(help)).accessibilityLabel(t(help))
    }
}

// Use a native popup with explicit, idempotent updates. The SwiftUI Picker's
// AppKitPopUpAdaptor was continuously rebuilding menus in the captured hang.
@MainActor
struct DelayPopUp: NSViewRepresentable {
    @Environment(\.hushLanguage) private var language
    private func t(_ source: String) -> String { L10n.text(source, language: language) }
    @Binding var value: Int
    let enabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator(value: $value) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.controlSize = .small
        button.font = HushTypography.regular(NSFont.smallSystemFontSize)
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectDelay(_:))
        button.setAccessibilityLabel(t("延迟时间"))
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        button.setAccessibilityLabel(t("延迟时间"))
        context.coordinator.value = $value
        let choices = Array(Set([0, 3, 5, 10, 15, 30, 60, 120, 300, value])).sorted()
        let titles = choices.map { $0 == 0 ? t("无延迟") : t("\($0) 秒") }
        if button.itemArray.map(\.tag) != choices || button.itemArray.map(\.title) != titles {
            button.removeAllItems()
            for (index, seconds) in choices.enumerated() {
                button.addItem(withTitle: titles[index])
                button.lastItem?.tag = seconds
            }
        }
        if button.selectedItem?.tag != value { button.selectItem(withTag: value) }
        if button.isEnabled != enabled { button.isEnabled = enabled }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? {
        CGSize(width: 90, height: 24)
    }

    @MainActor
    final class Coordinator: NSObject {
        var value: Binding<Int>
        init(value: Binding<Int>) { self.value = value }
        @objc func selectDelay(_ sender: NSPopUpButton) {
            guard let selected = sender.selectedItem?.tag, selected != value.wrappedValue else { return }
            value.wrappedValue = selected
        }
    }
}

@MainActor
private struct ApplicationIcon: View {
    @Environment(\.hushLanguage) private var language
    private func t(_ source: String) -> String { L10n.text(source, language: language) }
    let path: String
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon { Image(nsImage: icon).resizable() }
            else {
                Image(systemName: "app.dashed").resizable().scaledToFit()
                    .foregroundStyle(.secondary)
                    .help(t("应用路径不可用，请通过更多操作移除后重新添加"))
            }
        }
        .frame(width: 32, height: 32)
        .task(id: path) {
            // A nonexistent .app path makes NSWorkspace return a document icon.
            // Do not cache that as if it were the application's real icon.
            let url = URL(fileURLWithPath: path)
            if let bundle = Bundle(url: url), let executable = bundle.executableURL,
               FileManager.default.fileExists(atPath: executable.path) {
                icon = NSWorkspace.shared.icon(forFile: path)
            } else { icon = nil }
        }
    }
}

// Explicit button hierarchy avoids a tinted secondary glass button looking disabled.
private struct HushActionStyle: ViewModifier {
    var prominent = false
    func body(content: Content) -> some View {
        content.buttonStyle(HushButtonStyle(prominent: prominent))
    }
}

private struct HushButtonStyle: ButtonStyle {
    let prominent: Bool
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var colorScheme
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(HushTypography.font(size: 12, weight: .medium))
            .padding(.horizontal, 15).frame(height: 32)
            .foregroundStyle(prominent ? (colorScheme == .dark ? Color.black : Color.white) : Color.primary)
            .background {
                Capsule().fill(prominent ? hushAccent : Color(nsColor: .controlBackgroundColor))
            }
            .overlay(Capsule().strokeBorder(prominent ? Color.white.opacity(0.15) : Color.primary.opacity(0.10)))
            .overlay(Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.07 : 0)))
            .opacity(enabled ? 1 : 0.4)
            .contentShape(Capsule())
    }
}

private struct HushSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        content
            .background(Color(nsColor: .controlBackgroundColor).opacity(reduceTransparency ? 1 : 0.72), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.035)))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.10 : 0.035), radius: 12, y: 5)
    }
}
