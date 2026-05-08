import SwiftUI

enum ThemeColor: String, Codable, CaseIterable, Identifiable {
    case blue
    case purple
    case green
    case orange
    case red
    case pink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue: return "蓝色"
        case .purple: return "紫色"
        case .green: return "绿色"
        case .orange: return "橙色"
        case .red: return "红色"
        case .pink: return "粉色"
        }
    }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .pink: return .pink
        }
    }
}

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}
