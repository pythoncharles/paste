import AppKit
import Foundation

final class FileStorageManager {
    private let fileManager = FileManager.default

    var appSupportURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("paste", isDirectory: true)
    }

    var imagesURL: URL {
        appSupportURL.appendingPathComponent("images", isDirectory: true)
    }

    init() {
        try? fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
    }

    func saveImage(_ image: NSImage) throws -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dayFolder = imagesURL.appendingPathComponent(formatter.string(from: Date()), isDirectory: true)
        try fileManager.createDirectory(at: dayFolder, withIntermediateDirectories: true)

        let fileURL = dayFolder.appendingPathComponent("\(UUID().uuidString).png")
        guard let data = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }

        try data.write(to: fileURL, options: .atomic)
        return fileURL.path
    }

    func deleteImageIfNeeded(path: String?) {
        guard let path, !path.isEmpty else { return }
        try? fileManager.removeItem(atPath: path)
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
