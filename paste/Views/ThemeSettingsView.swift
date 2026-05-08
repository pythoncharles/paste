import SwiftUI

struct ThemeSettingsView: View {
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        Form {
            Picker("主题颜色", selection: $themeManager.themeColor) {
                ForEach(ThemeColor.allCases) { theme in
                    HStack {
                        Circle()
                            .fill(theme.color)
                            .frame(width: 10, height: 10)
                        Text(theme.displayName)
                    }
                    .tag(theme)
                }
            }
            .pickerStyle(.menu)

            Picker("外观模式", selection: $themeManager.appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .formStyle(.grouped)
    }
}
