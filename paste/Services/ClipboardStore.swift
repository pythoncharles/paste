import AppKit
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published var searchText: String = "" {
        didSet { reload() }
    }

    var isPaused: Bool { settingsManager.settings.isPaused }

    private let settingsManager: SettingsManager
    private let fileStorageManager = FileStorageManager()
    private let parser = ClipboardParser()
    private let securityFilter = SecurityFilter()
    private lazy var storageManager = StorageManager(fileStorageManager: fileStorageManager)
    private lazy var watcher = ClipboardWatcher { [weak self] pasteboard in
        Task { @MainActor in self?.handlePasteboardChanged(pasteboard) }
    }

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        reload()
    }

    func start() {
        watcher.start()
        reload()
    }

    func stop() {
        watcher.stop()
    }

    func handlePasteboardChanged(_ pasteboard: NSPasteboard) {
        guard !settingsManager.settings.isPaused else { return }
        guard let parsed = parser.parse(pasteboard) else { return }

        let sourceApplication = NSWorkspace.shared.frontmostApplication
        let sourceApp = sourceApplication?.localizedName
        let sourceBundleIdentifier = sourceApplication?.bundleIdentifier
        if securityFilter.shouldSkip(sourceApp: sourceApp, text: parsed.content ?? parsed.filePath, settings: settingsManager.settings) {
            return
        }

        var imagePath: String?
        if let image = parsed.image {
            imagePath = try? fileStorageManager.saveImage(image)
        }

        let item = ClipboardItem(
            id: UUID(),
            type: parsed.type,
            content: parsed.content,
            imagePath: imagePath,
            filePath: parsed.filePath,
            preview: parsed.preview,
            hash: parsed.hash,
            sourceApp: sourceApp,
            sourceBundleIdentifier: sourceBundleIdentifier,
            isFavorite: false,
            createdAt: Date()
        )

        storageManager.insert(item)
        storageManager.enforceRetention(
            maxItems: settingsManager.settings.maxItems,
            maxDays: settingsManager.settings.maxDays,
            fileStorageManager: fileStorageManager
        )
        reload()
    }

    func restore(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text:
            if let content = item.content {
                pasteboard.setString(content, forType: .string)
            }
        case .url:
            if let content = item.content, let url = URL(string: content) {
                pasteboard.writeObjects([url as NSURL])
                pasteboard.setString(content, forType: .string)
            }
        case .image:
            if let path = item.imagePath, let image = NSImage(contentsOfFile: path) {
                pasteboard.writeObjects([image])
            }
        case .file:
            if let path = item.filePath {
                pasteboard.writeObjects([URL(fileURLWithPath: path) as NSURL])
            }
        }

        watcher.markCurrentPasteboardAsHandled()
    }

    func toggleFavorite(_ item: ClipboardItem) {
        storageManager.updateFavorite(id: item.id, isFavorite: !item.isFavorite)
        reload()
    }

    func delete(_ item: ClipboardItem) {
        storageManager.delete(item, fileStorageManager: fileStorageManager)
        reload()
    }

    func clearAll() {
        storageManager.clearAll(fileStorageManager: fileStorageManager)
        reload()
    }

    func setPaused(_ paused: Bool) {
        settingsManager.update { $0.isPaused = paused }
        objectWillChange.send()
    }

    func reload() {
        items = storageManager.fetchItems(search: searchText)
    }
}
