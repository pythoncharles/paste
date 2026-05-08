import Foundation

struct AppSettings: Codable, Equatable {
    var isPaused: Bool = false
    var maxItems: Int = 100
    var maxDays: Int = 7
    var blacklistedApps: [String] = ["1Password", "Keychain Access"]
    var launchAtLogin: Bool = false
    var themeColor: ThemeColor = .blue
    var appearanceMode: AppearanceMode = .system
}
