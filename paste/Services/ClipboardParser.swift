import AppKit
import CryptoKit
import Foundation

struct ParsedClipboardItem {
    let type: ClipboardItemType
    let content: String?
    let image: NSImage?
    let filePath: String?
    let preview: String
    let hash: String
}

struct ClipboardParser {
    func parse(_ pasteboard: NSPasteboard) -> ParsedClipboardItem? {
        if let image = parseImage(pasteboard) {
            return image
        }

        if let file = parseFile(pasteboard) {
            return file
        }

        if let url = parseURL(pasteboard) {
            return url
        }

        if let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return ParsedClipboardItem(
                type: .text,
                content: text,
                image: nil,
                filePath: nil,
                preview: text.singleLinePreview,
                hash: Self.hash("text:\(text)")
            )
        }

        return nil
    }

    private func parseImage(_ pasteboard: NSPasteboard) -> ParsedClipboardItem? {
        let candidates: [NSPasteboard.PasteboardType] = [.png, .tiff]
        for type in candidates {
            if let data = pasteboard.data(forType: type), let image = NSImage(data: data) {
                return ParsedClipboardItem(
                    type: .image,
                    content: nil,
                    image: image,
                    filePath: nil,
                    preview: "图片 \(Int(image.size.width))x\(Int(image.size.height))",
                    hash: Self.hash(data)
                )
            }
        }
        return nil
    }

    private func parseFile(_ pasteboard: NSPasteboard) -> ParsedClipboardItem? {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let url = urls.first,
              url.isFileURL else {
            return nil
        }

        return ParsedClipboardItem(
            type: .file,
            content: url.path,
            image: nil,
            filePath: url.path,
            preview: url.lastPathComponent,
            hash: Self.hash("file:\(url.path)")
        )
    }

    private func parseURL(_ pasteboard: NSPasteboard) -> ParsedClipboardItem? {
        if let url = NSURL(from: pasteboard) as URL?, !url.isFileURL {
            return ParsedClipboardItem(
                type: .url,
                content: url.absoluteString,
                image: nil,
                filePath: nil,
                preview: url.absoluteString,
                hash: Self.hash("url:\(url.absoluteString)")
            )
        }

        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }

        return ParsedClipboardItem(
            type: .url,
            content: text,
            image: nil,
            filePath: nil,
            preview: text,
            hash: Self.hash("url:\(text)")
        )
    }

    private static func hash(_ value: String) -> String {
        hash(Data(value.utf8))
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private extension String {
    var singleLinePreview: String {
        let cleaned = replacingOccurrences(of: "\n", with: " ")
        return cleaned.count > 160 ? String(cleaned.prefix(160)) + "..." : cleaned
    }
}
