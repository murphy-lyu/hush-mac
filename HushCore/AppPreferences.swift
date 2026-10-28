import Foundation
import Combine

@MainActor
final class AppPreferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var showDockIcon: Bool { didSet { defaults.set(showDockIcon, forKey: "showDockIcon") } }
    @Published var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: "showMenuBarIcon") } }
    @Published var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: "language") } }
    var effectiveLanguage: AppLanguage { language.resolved() }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showDockIcon = defaults.bool(forKey: "showDockIcon")
        showMenuBarIcon = defaults.object(forKey: "showMenuBarIcon") == nil ? true : defaults.bool(forKey: "showMenuBarIcon")
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .system
    }
}
