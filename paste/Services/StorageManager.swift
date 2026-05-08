import Foundation
import SQLite3

final class StorageManager {
    private var db: OpaquePointer?
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(fileStorageManager: FileStorageManager) {
        let dbURL = fileStorageManager.appSupportURL.appendingPathComponent("paste.sqlite")
        try? FileManager.default.createDirectory(at: fileStorageManager.appSupportURL, withIntermediateDirectories: true)

        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            NSLog("Failed to open SQLite database")
        }
        createSchema()
    }

    deinit {
        sqlite3_close(db)
    }

    func fetchItems(search: String = "") -> [ClipboardItem] {
        let hasSearch = !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let sql = hasSearch
            ? """
              SELECT id, type, content, image_path, file_path, preview, hash, source_app, source_bundle_identifier, is_favorite, created_at
              FROM clipboard_items
              WHERE preview LIKE ? OR content LIKE ?
              ORDER BY created_at DESC;
              """
            : """
              SELECT id, type, content, image_path, file_path, preview, hash, source_app, source_bundle_identifier, is_favorite, created_at
              FROM clipboard_items
              ORDER BY created_at DESC;
              """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }

        if hasSearch {
            bind("%\(search)%", to: statement, at: 1)
            bind("%\(search)%", to: statement, at: 2)
        }

        var items: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let item = item(from: statement) else { continue }
            items.append(item)
        }
        return items
    }

    func insert(_ item: ClipboardItem) {
        let sql = """
        INSERT OR IGNORE INTO clipboard_items
        (id, type, content, image_path, file_path, preview, hash, source_app, source_bundle_identifier, is_favorite, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }

        bind(item.id.uuidString, to: statement, at: 1)
        bind(item.type.rawValue, to: statement, at: 2)
        bind(item.content, to: statement, at: 3)
        bind(item.imagePath, to: statement, at: 4)
        bind(item.filePath, to: statement, at: 5)
        bind(item.preview, to: statement, at: 6)
        bind(item.hash, to: statement, at: 7)
        bind(item.sourceApp, to: statement, at: 8)
        bind(item.sourceBundleIdentifier, to: statement, at: 9)
        sqlite3_bind_int(statement, 10, item.isFavorite ? 1 : 0)
        bind(dateFormatter.string(from: item.createdAt), to: statement, at: 11)
        sqlite3_step(statement)
    }

    func updateFavorite(id: UUID, isFavorite: Bool) {
        let sql = "UPDATE clipboard_items SET is_favorite = ? WHERE id = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, isFavorite ? 1 : 0)
        bind(id.uuidString, to: statement, at: 2)
        sqlite3_step(statement)
    }

    func clearAll(fileStorageManager: FileStorageManager) {
        fetchItems().forEach { fileStorageManager.deleteImageIfNeeded(path: $0.imagePath) }
        execute("DELETE FROM clipboard_items;")
    }

    func delete(_ item: ClipboardItem, fileStorageManager: FileStorageManager) {
        fileStorageManager.deleteImageIfNeeded(path: item.imagePath)
        delete(id: item.id)
    }

    func enforceRetention(maxItems: Int, maxDays: Int, fileStorageManager: FileStorageManager) {
        let overflow = removableItems(sql: """
            SELECT id, type, content, image_path, file_path, preview, hash, source_app, source_bundle_identifier, is_favorite, created_at
            FROM clipboard_items
            WHERE is_favorite = 0
            AND id NOT IN (
                SELECT id FROM clipboard_items
                WHERE is_favorite = 0
                ORDER BY created_at DESC
                LIMIT \(maxItems)
            );
            """)

        let cutoff = Calendar.current.date(byAdding: .day, value: -maxDays, to: Date()) ?? Date()
        let old = removableItems(
            sql: """
            SELECT id, type, content, image_path, file_path, preview, hash, source_app, source_bundle_identifier, is_favorite, created_at
            FROM clipboard_items
            WHERE is_favorite = 0 AND created_at < ?;
            """,
            parameter: dateFormatter.string(from: cutoff)
        )

        let ids = Set((overflow + old).map(\.id))
        for item in overflow + old where ids.contains(item.id) {
            fileStorageManager.deleteImageIfNeeded(path: item.imagePath)
        }

        ids.forEach { delete(id: $0) }
    }

    private func createSchema() {
        execute("""
        CREATE TABLE IF NOT EXISTS clipboard_items (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            content TEXT,
            image_path TEXT,
            file_path TEXT,
            preview TEXT,
            hash TEXT NOT NULL UNIQUE,
            source_app TEXT,
            source_bundle_identifier TEXT,
            is_favorite INTEGER DEFAULT 0,
            created_at DATETIME NOT NULL
        );
        """)
        addColumnIfNeeded(name: "source_bundle_identifier", definition: "TEXT")
        execute("CREATE INDEX IF NOT EXISTS idx_clipboard_created_at ON clipboard_items(created_at DESC);")
        execute("CREATE INDEX IF NOT EXISTS idx_clipboard_type ON clipboard_items(type);")
    }

    private func removableItems(sql: String, parameter: String? = nil) -> [ClipboardItem] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        if let parameter {
            bind(parameter, to: statement, at: 1)
        }

        var items: [ClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let item = item(from: statement) else { continue }
            items.append(item)
        }
        return items
    }

    private func delete(id: UUID) {
        let sql = "DELETE FROM clipboard_items WHERE id = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        bind(id.uuidString, to: statement, at: 1)
        sqlite3_step(statement)
    }

    private func execute(_ sql: String) {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            NSLog("SQLite error: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private func item(from statement: OpaquePointer?) -> ClipboardItem? {
        guard let idText = text(statement, 0),
              let id = UUID(uuidString: idText),
              let typeText = text(statement, 1),
              let type = ClipboardItemType(rawValue: typeText),
              let preview = text(statement, 5),
              let hash = text(statement, 6),
              let createdAtText = text(statement, 10),
              let createdAt = dateFormatter.date(from: createdAtText) else {
            return nil
        }

        return ClipboardItem(
            id: id,
            type: type,
            content: text(statement, 2),
            imagePath: text(statement, 3),
            filePath: text(statement, 4),
            preview: preview,
            hash: hash,
            sourceApp: text(statement, 7),
            sourceBundleIdentifier: text(statement, 8),
            isFavorite: sqlite3_column_int(statement, 9) == 1,
            createdAt: createdAt
        )
    }

    private func addColumnIfNeeded(name: String, definition: String) {
        let existing = tableColumns()
        guard !existing.contains(name) else { return }
        execute("ALTER TABLE clipboard_items ADD COLUMN \(name) \(definition);")
    }

    private func tableColumns() -> Set<String> {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(clipboard_items);", -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var names = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let name = text(statement, 1) {
                names.insert(name)
            }
        }
        return names
    }

    private func bind(_ value: String?, to statement: OpaquePointer?, at index: Int32) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
    }

    private func text(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
