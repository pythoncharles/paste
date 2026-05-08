import Foundation

struct SecurityFilter {
    private let sensitiveTokens = [
        "password=",
        "Authorization:",
        "Bearer ",
        "sk-",
        "AKIA",
        "-----BEGIN PRIVATE KEY-----"
    ]

    func shouldSkip(sourceApp: String?, text: String?, settings: AppSettings) -> Bool {
        if let sourceApp,
           settings.blacklistedApps.contains(where: { sourceApp.localizedCaseInsensitiveContains($0) }) {
            return true
        }

        guard let text else { return false }
        return sensitiveTokens.contains { text.localizedCaseInsensitiveContains($0) }
    }
}
