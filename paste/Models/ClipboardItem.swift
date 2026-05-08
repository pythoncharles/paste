import Foundation

enum ClipboardItemType: String, Codable, CaseIterable, Identifiable {
    case text
    case url
    case image
    case file

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: return "文本"
        case .url: return "URL"
        case .image: return "图片"
        case .file: return "文件"
        }
    }
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ClipboardItemType
    var content: String?
    var imagePath: String?
    var filePath: String?
    var preview: String
    var hash: String
    var sourceApp: String?
    var sourceBundleIdentifier: String?
    var isFavorite: Bool
    var createdAt: Date
}
