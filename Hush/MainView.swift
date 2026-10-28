import SwiftUI
import AppKit
import UniformTypeIdentifiers

private let hushAccent = Color(red: 0.42, green: 0.39, blue: 0.70)

struct MainView: View {
    @ObservedObject var store: StartupStore
    @ObservedObject var runner: LaunchRunner
    @ObservedObject var login: LoginService
    @State private var showingHistory = false
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.6)
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 4) {
                    sectionButton("启动应用", selected: !showingHistory) { showingHistory = false }
                    sectionButton("启动记录", selected: showingHistory) { showingHistory = true }
                    Spacer()
                    if showingHistory {
                        Button("清空记录") { runner.clearHistory() }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                            .disabled(runner.records.isEmpty)
                    } else {
                        Text("\(store.items.filter(\.enabled).count) 个已启用")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                if showingHistory { history } else { applications }
            }
            .padding(24)
            Divider().opacity(0.6)
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(hushAccent)
        .frame(minWidth: 800, minHeight: 520)
        .alert("需要处理", isPresented: Binding(
            get: { store.error != nil || login.error != nil },
            set: { if !$0 { store.error = nil; login.error = nil } }
        )) {
            Button("好", role: .cancel) { store.error = nil; login.error = nil }
        } message: { Text(store.error ?? login.error ?? "") }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 15) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(hushAccent)
                .frame(width: 54, height: 54)
                .background(hushAccent.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 5) {
                Text("Hush").font(.system(size: 25, weight: .semibold, design: .rounded))
                Text("应用准备就绪，桌面保持安静。")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            if runner.isRunning {
                Button { runner.cancel() } label: { Label("停止", systemImage: "stop.fill") }
                    .controlSize(.large)
            } else {
                Button { runner.start(store.items) } label: { Label("测试全部", systemImage: "play.fill") }
                    .controlSize(.large)
                    .disabled(store.loadFailed || !store.items.contains(where: \.enabled))
                    .help("按列表顺序、延迟和网络等待条件启动已启用的应用；已运行的应用会跳过")
            }
            Button(action: addApplications) { Label("添加应用", systemImage: "plus") }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(runner.isRunning || store.loadFailed)
                .keyboardShortcut("o", modifiers: .command)
        }
        .padding(.horizontal, 26).padding(.vertical, 22)
    }

    private func sectionButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 13, weight: selected ? .semibold : .regular))
                .padding(.horizontal, 13).padding(.vertical, 7)
                .background(selected ? hushAccent.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(selected ? hushAccent : .secondary)
        }.buttonStyle(.plain)
    }

    private var applications: some View {
        VStack(spacing: 14) {
            if store.items.isEmpty {
                VStack(spacing: 13) {
                    Image(systemName: "sun.horizon")
                        .font(.system(size: 40, weight: .ultraLight)).foregroundStyle(hushAccent)
                    Text("从一个安静的早晨开始")
                        .font(.system(size: 18, weight: .medium))
                    Text("添加登录后需要的应用，设置隐藏、延迟、网络等待与启动顺序。")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    Button("选择应用…", action: addApplications)
                        .padding(.top, 4).disabled(store.loadFailed)
                    Text("也可以把应用拖到这里")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(dropTargeted ? hushAccent : Color.primary.opacity(0.07), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("网络工具优先，其余按顺序").frame(maxWidth: .infinity, alignment: .leading)
                        Text("联网后").frame(width: 52)
                        Text("隐藏").frame(width: 52)
                        Text("延迟").frame(width: 90)
                        Text("顺序 / 测试").frame(width: 136)
                    }
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    .padding(.horizontal, 18).padding(.vertical, 11)
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
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(dropTargeted ? hushAccent : Color.primary.opacity(0.06)))
            }
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "info.circle").padding(.top, 1)
                Text("网络工具优先，其余按顺序。勾选“联网后”时，网络工具等待基础网络，其他应用检查 HTTPS；同一轮复用近期结果，网络变化时重新检测。")
                    .fixedSize(horizontal: false, vertical: true)
                Button("登录项设置") { login.openSettings() }.buttonStyle(.link)
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hushAccent.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
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
                    Text("还没有启动记录").font(.system(size: 15, weight: .medium))
                    Text("测试启动后，可以在这里查看结果。")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(runner.records) { record in
                            HStack(spacing: 12) {
                                Image(systemName: record.failed ? "exclamationmark.circle" : "checkmark.circle")
                                    .foregroundStyle(record.failed ? Color.orange : hushAccent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.name).font(.system(size: 13, weight: .medium))
                                    Text(record.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                                Spacer()
                                Text(record.date, format: .dateTime.month().day().hour().minute().second())
                                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                            }.padding(15)
                            Divider().padding(.leading, 43).opacity(0.5)
                        }
                    }
                }.background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if login.allowsSystemChanges {
                Toggle("登录时运行 Hush", isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) }))
                    .toggleStyle(.checkbox).font(.system(size: 12))
                    .help("开启后，登录时按列表启动应用；Hush 管理窗口保持关闭")
            } else {
                Text("测试窗口 · 不修改系统登录项").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if login.needsApproval {
                Button("前往允许") { login.openSettings() }.font(.system(size: 11))
            }
            Spacer()
            if runner.isRunning { ProgressView().controlSize(.small).scaleEffect(0.8) }
            Text(runner.historyWarning ?? runner.status).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                .help(runner.historyWarning ?? runner.status)
            Circle().fill(runner.isRunning ? hushAccent : Color.green.opacity(0.7)).frame(width: 6, height: 6)
        }
        .padding(.horizontal, 25).padding(.vertical, 16)
    }

    private func addApplications() {
        let panel = NSOpenPanel()
        panel.title = "添加启动应用"
        panel.prompt = "添加"
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
            store.error = "请选择有效的 macOS 应用（.app）。"; return
        }
        guard bundle.bundleIdentifier != Bundle.main.bundleIdentifier else {
            store.error = "Hush 的登录启动请使用窗口底部的开关。"; return
        }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        store.add(StartupItem(name: name, path: url.path, bundleIdentifier: bundle.bundleIdentifier, bookmark: bookmark))
    }
}

private struct AppRow: View {
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
            Toggle("启用 \(item.name)", isOn: Binding(get: { item.enabled }, set: { value in update { $0.enabled = value } }))
                .labelsHidden().toggleStyle(.checkbox).disabled(running)
            ApplicationIcon(path: item.path)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(active ? "正在处理…" : (item.enabled ? "第 \(index + 1) 项" : "已暂停"))
                    .font(.system(size: 10)).foregroundStyle(active ? hushAccent : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).help(item.path)
            Toggle("等待网络可用后启动 \(item.name)", isOn: Binding(get: { item.waitForNetwork }, set: { value in update { $0.waitForNetwork = value } }))
                .labelsHidden().toggleStyle(.checkbox).frame(width: 52).disabled(running)
                .help(item.providesNetwork ? "Wi-Fi 或有线取得有效 IP 和网关后即可启动，不检查外网或代理。未就绪时退避重试，最多等待 5 分钟。" : "首次间隔 0.5 秒确认 2 次 HTTPS 成功；同一轮 15 秒内且网络状态未变时复用结果。失败退避重试，最多等待 5 分钟。不保证各应用服务均可达。")
            Toggle("隐藏启动 \(item.name)", isOn: Binding(get: { item.hidden }, set: { value in update { $0.hidden = value } }))
                .labelsHidden().toggleStyle(.checkbox).frame(width: 52).disabled(running)
                .help("请求隐藏启动，效果取决于应用；不会最小化到 Dock")
            DelayPopUp(value: Binding(get: { item.delay }, set: { value in update { $0.delay = value } }),
                       enabled: !running)
                .frame(width: 90, height: 24)
            HStack(spacing: 3) {
                rowButton("chevron.up", help: "上移", disabled: running || index == 0) { move(-1) }
                rowButton("chevron.down", help: "下移", disabled: running || index == count - 1) { move(1) }
                rowButton("play", help: "测试此应用（含延迟与网络等待）", disabled: running, action: test)
                Menu {
                    Button("在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)]) }
                    Divider()
                    Button("从列表移除", role: .destructive, action: remove).disabled(running)
                } label: { Image(systemName: "ellipsis").frame(width: 22, height: 26) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel("\(item.name) 的更多操作")
            }.frame(width: 136)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(active ? hushAccent.opacity(0.05) : .clear)
        .opacity(item.enabled ? 1 : 0.60)
    }

    private func rowButton(_ symbol: String, help: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .medium)).frame(width: 24, height: 26)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(.secondary).disabled(disabled).help(help).accessibilityLabel(help)
    }
}

// Use a native popup with explicit, idempotent updates. The SwiftUI Picker's
// AppKitPopUpAdaptor was continuously rebuilding menus in the captured hang.
@MainActor
struct DelayPopUp: NSViewRepresentable {
    @Binding var value: Int
    let enabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator(value: $value) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.controlSize = .small
        button.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectDelay(_:))
        button.setAccessibilityLabel("延迟时间")
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.value = $value
        let choices = Array(Set([0, 3, 5, 10, 15, 30, 60, 120, 300, value])).sorted()
        if button.itemArray.map(\.tag) != choices {
            button.removeAllItems()
            for seconds in choices {
                button.addItem(withTitle: seconds == 0 ? "无延迟" : "\(seconds) 秒")
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
    let path: String
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon { Image(nsImage: icon).resizable() }
            else { Color.clear }
        }
        .frame(width: 32, height: 32)
        .task(id: path) { icon = NSWorkspace.shared.icon(forFile: path) }
    }
}
