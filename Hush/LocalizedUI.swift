import SwiftUI

private struct HushLanguageKey: EnvironmentKey {
    static let defaultValue = AppLanguage.system.resolved()
}
extension EnvironmentValues {
    var hushLanguage: AppLanguage {
        get { self[HushLanguageKey.self] }
        set { self[HushLanguageKey.self] = newValue }
    }
}
