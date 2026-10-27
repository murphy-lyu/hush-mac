import AppKit
import ServiceManagement
import Combine

@MainActor
final class LoginService: ObservableObject {
    let allowsSystemChanges: Bool
    @Published private(set) var enabled = false
    @Published private(set) var needsApproval = false
    @Published var error: String?

    init(allowsSystemChanges: Bool = true) {
        self.allowsSystemChanges = allowsSystemChanges
        if allowsSystemChanges { refresh() }
    }
    func refresh() {
        guard allowsSystemChanges else { return }
        let status = SMAppService.mainApp.status
        let nextEnabled = status == .enabled || status == .requiresApproval
        let nextNeedsApproval = status == .requiresApproval
        if enabled != nextEnabled { enabled = nextEnabled }
        if needsApproval != nextNeedsApproval { needsApproval = nextNeedsApproval }
    }
    func setEnabled(_ enabled: Bool) {
        guard allowsSystemChanges else { return }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { self.error = "无法更新登录启动：\(error.localizedDescription)" }
        refresh()
    }
    func openSettings() {
        guard allowsSystemChanges else { return }
        SMAppService.openSystemSettingsLoginItems()
    }
}
