import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        TabView {
            general
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            ThemeSettingsView(themeManager: themeManager)
                .tabItem {
                    Label("主题", systemImage: "paintpalette")
                }
        }
        .padding(20)
        .tint(themeManager.accentColor)
    }

    private var general: some View {
        Form {
            Toggle("暂停记录", isOn: Binding(
                get: { settingsManager.settings.isPaused },
                set: { store.setPaused($0) }
            ))

            Toggle("开机启动", isOn: Binding(
                get: { settingsManager.settings.launchAtLogin },
                set: { settingsManager.setLaunchAtLogin($0) }
            ))

            Stepper("最多保留 \(settingsManager.settings.maxItems) 条", value: Binding(
                get: { settingsManager.settings.maxItems },
                set: { newValue in settingsManager.update { $0.maxItems = newValue.clamped(to: 20...500) } }
            ), in: 20...500, step: 10)

            Stepper("最多保留 \(settingsManager.settings.maxDays) 天", value: Binding(
                get: { settingsManager.settings.maxDays },
                set: { newValue in settingsManager.update { $0.maxDays = newValue.clamped(to: 1...90) } }
            ), in: 1...90)

            Button(role: .destructive) {
                store.clearAll()
            } label: {
                Label("清空全部记录", systemImage: "trash")
            }
        }
        .formStyle(.grouped)
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
