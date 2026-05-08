import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 7) {
                ClipboardPreviewView(item: item)
                    .frame(width: 44, height: 44)

                Text(sourceAppName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 76)
            }
            .frame(width: 76)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    Spacer()
                    Text(item.createdAt.copyTimeText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                HStack(alignment: .center, spacing: 10) {
                    if item.type == .image,
                       let path = item.imagePath,
                       let image = NSImage(contentsOfFile: path) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Text(item.preview)
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 0)
                }
                .frame(height: 38)

                HStack(spacing: 4) {
                    Text(item.detailText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(height: 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private var sourceAppName: String {
        guard let sourceApp = item.sourceApp, !sourceApp.isEmpty else {
            return "未知"
        }
        return sourceApp
    }
}

extension ClipboardItem {
    var detailText: String {
        switch type {
        case .text:
            return "\(contentOrPreview.count) 字符"
        case .url:
            return "\(contentOrPreview.count) 字符 · URL"
        case .image:
            return imageDetailText
        case .file:
            return fileDetailText
        }
    }

    private var contentOrPreview: String {
        content ?? filePath ?? preview
    }

    private var imageDetailText: String {
        var parts: [String] = []
        if let path = imagePath, let image = NSImage(contentsOfFile: path) {
            parts.append("\(Int(image.size.width))x\(Int(image.size.height)) px")
        }
        if let path = imagePath, let size = fileSizeText(path: path) {
            parts.append(size)
        }
        return parts.isEmpty ? "图片" : parts.joined(separator: " · ")
    }

    private var fileDetailText: String {
        var parts: [String] = []
        if let path = filePath {
            parts.append("\(path.count) 字符路径")
            if let size = fileSizeText(path: path) {
                parts.append(size)
            }
        }
        return parts.isEmpty ? "\(contentOrPreview.count) 字符" : parts.joined(separator: " · ")
    }

    private func fileSizeText(path: String) -> String? {
        guard let bytes = try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber else {
            return nil
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes.int64Value)
    }
}

private extension Date {
    var copyTimeText: String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "zh_CN")
        timeFormatter.dateFormat = "HH:mm"

        if calendar.isDateInToday(self) {
            return timeFormatter.string(from: self)
        }

        if calendar.isDateInYesterday(self) {
            return "昨天 \(timeFormatter.string(from: self))"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "M/d HH:mm"
        return dateFormatter.string(from: self)
    }
}
