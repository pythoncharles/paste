import SwiftUI

@MainActor
final class ThemeManager: ObservableObject {
    @Published var themeColor: ThemeColor {
        didSet {
            settingsManager.update { $0.themeColor = themeColor }
        }
    }

    @Published var appearanceMode: AppearanceMode {
        didSet {
            settingsManager.update { $0.appearanceMode = appearanceMode }
            onAppearanceChanged?()
        }
    }

    var accentColor: Color { themeColor.color }
    var onAppearanceChanged: (() -> Void)?

    private let settingsManager: SettingsManager

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        self.themeColor = settingsManager.settings.themeColor
        self.appearanceMode = settingsManager.settings.appearanceMode
    }
}
