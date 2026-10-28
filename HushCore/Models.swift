import Foundation

struct StartupItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var path: String
    var bundleIdentifier: String?
    var bookmark: Data? = nil
    var enabled = true
    var hidden = true
    var delay = 0
    var waitForNetwork = false

    // These applications need local link readiness, not internet/proxy readiness.
    var providesNetwork: Bool {
        let identifiers: Set<String> = ["com.nssurge.surge-mac", "io.tailscale.ipn.macsys", "io.tailscale.ipn.macos"]
        if let bundleIdentifier, identifiers.contains(bundleIdentifier) { return true }
        return ["/Applications/Surge.app", "/Applications/Tailscale.app"].contains(path)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, path, bundleIdentifier, bookmark, enabled, hidden, delay, waitForNetwork
    }

    init(id: UUID = UUID(), name: String, path: String, bundleIdentifier: String? = nil,
         bookmark: Data? = nil, enabled: Bool = true, hidden: Bool = true, delay: Int = 0,
         waitForNetwork: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.bundleIdentifier = bundleIdentifier
        self.bookmark = bookmark
        self.enabled = enabled
        self.hidden = hidden
        self.delay = delay
        self.waitForNetwork = waitForNetwork
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        path = try values.decode(String.self, forKey: .path)
        bundleIdentifier = try values.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        bookmark = try values.decodeIfPresent(Data.self, forKey: .bookmark)
        enabled = try values.decode(Bool.self, forKey: .enabled)
        hidden = try values.decode(Bool.self, forKey: .hidden)
        delay = try values.decode(Int.self, forKey: .delay)
        // Existing version-1 lists retain their original launch behavior.
        waitForNetwork = try values.decodeIfPresent(Bool.self, forKey: .waitForNetwork) ?? false
    }
}

struct Configuration: Codable, Equatable {
    var version = 1
    var items: [StartupItem] = []

    func validated() throws -> Configuration {
        guard version == 1 else { throw HushError.message("不支持此配置版本，请更新 Hush 后重试。") }
        guard Set(items.map(\.id)).count == items.count,
              Set(items.map(\.path)).count == items.count,
              items.allSatisfy({ (0...300).contains($0.delay) && $0.path.hasPrefix("/") })
        else { throw HushError.message("配置内容无效，原文件已保留。") }
        return self
    }
}

enum HushError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}

struct RunRecord: Identifiable, Codable {
    var id = UUID()
    var date = Date()
    var name: String
    var detail: String
    var failed = false
    var timing: LaunchTiming? = nil
}

struct LaunchTiming: Codable {
    let delay: TimeInterval
    let network: TimeInterval
    let launch: TimeInterval
    let total: TimeInterval
}

protocol ConfigurationPersistence {
    func load() throws -> Configuration
    func save(_ configuration: Configuration) throws
}

final class JSONConfigurationPersistence: ConfigurationPersistence {
    let url: URL
    init(url: URL) { self.url = url }
    func load() throws -> Configuration {
        guard FileManager.default.fileExists(atPath: url.path) else { return Configuration() }
        return try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: url)).validated()
    }
    func save(_ configuration: Configuration) throws {
        let valid = try configuration.validated()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(valid).write(to: url, options: .atomic)
    }
}
