import Foundation
import Combine

@MainActor
final class StartupStore: ObservableObject {
    @Published private(set) var configuration = Configuration()
    @Published var error: String?
    @Published private(set) var loadFailed = false
    private let persistence: ConfigurationPersistence
    var items: [StartupItem] { configuration.items }

    init(persistence: ConfigurationPersistence) {
        self.persistence = persistence
        do { configuration = try persistence.load() }
        catch { loadFailed = true; self.error = "无法读取启动列表：\(error.localizedDescription)" }
    }

    @discardableResult
    func commit(_ mutation: (inout Configuration) -> Void) -> Bool {
        guard !loadFailed else { error = "配置读取失败，已暂停编辑，避免覆盖原文件。请修复配置后重新打开 Hush。"; return false }
        var next = configuration
        mutation(&next)
        guard next != configuration else { return true }
        do {
            try persistence.save(next)
            configuration = next
            return true
        } catch { self.error = "保存失败：\(error.localizedDescription)"; return false }
    }

    func add(_ item: StartupItem) {
        guard !items.contains(where: {
            $0.path == item.path || (item.bundleIdentifier != nil && $0.bundleIdentifier == item.bundleIdentifier)
        }) else { error = "\(item.name) 已在启动列表中。"; return }
        commit { $0.items.append(item) }
    }
    func update(_ id: UUID, _ mutation: (inout StartupItem) -> Void) {
        commit { config in
            if let index = config.items.firstIndex(where: { $0.id == id }) { mutation(&config.items[index]) }
        }
    }
    func remove(_ id: UUID) { commit { $0.items.removeAll { $0.id == id } } }
    func move(_ id: UUID, by distance: Int) {
        guard let source = items.firstIndex(where: { $0.id == id }), items.indices.contains(source + distance) else { return }
        commit { $0.items.swapAt(source, source + distance) }
    }
}
