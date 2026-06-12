import SwiftUI

struct ClipboardListView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var themeManager: ThemeManager
    @State private var selectedFilter: ClipboardFilter = .all
    @State private var selectedItemID: UUID?
    @State private var previewedItemID: UUID?
    @State private var keyMonitor: Any?
    @State private var rowMidYs: [UUID: CGFloat] = [:]

    var body: some View {
        VStack(spacing: 0) {
            header

            if filteredItems.isEmpty {
                EmptyStateView(text: "暂无剪切板记录", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                listContent
            }

            footer
        }
        .tint(themeManager.accentColor)
        .onAppear {
            installSpacePreviewMonitor()
        }
        .onDisappear {
            removeSpacePreviewMonitor()
        }
    }

    private var listContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id("list-top")

                    ForEach(groupedItems) { group in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(group.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 6)

                            VStack(spacing: 0) {
                                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                    ClipboardItemRow(item: item)
                                        .padding(.leading, 16)
                                        .padding(.trailing, 26)
                                        .padding(.vertical, 6)
                                        .background(rowBackground(for: item))
                                        .background(RowMidYReader { midY in
                                            rowMidYs[item.id] = midY
                                        })
                                        .contentShape(Rectangle())
                                        .onHover { hovering in
                                            if hovering {
                                                select(item)
                                            }
                                        }
                                        .onTapGesture {
                                            select(item)
                                            store.restore(item)
                                        }
                                        .contextMenu {
                                            itemContextMenu(for: item)
                                        }

                                    if index < group.items.count - 1 {
                                        Divider()
                                            .padding(.horizontal, 28)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            .onChange(of: selectedFilter) { _ in
                selectedItemID = nil
                previewedItemID = nil
                rowMidYs = [:]
                NotificationCenter.default.post(name: .hidePastePreview, object: nil)
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo("list-top", anchor: .top)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private func rowBackground(for item: ClipboardItem) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selectedItemID == item.id ? themeManager.accentColor.opacity(0.12) : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selectedItemID == item.id ? themeManager.accentColor.opacity(0.55) : .clear, lineWidth: 1)
            )
            .padding(.leading, 8)
            .padding(.trailing, 18)
    }

    @ViewBuilder
    private func itemContextMenu(for item: ClipboardItem) -> some View {
        Button {
            select(item)
            store.restore(item)
        } label: {
            Label("复制", systemImage: "doc.on.doc")
        }

        Button {
            select(item, updateOpenPreview: false)
            togglePreview(for: item)
        } label: {
            Label("预览", systemImage: "eye")
        }

        Button {
            select(item)
            store.toggleFavorite(item)
        } label: {
            Label(item.isFavorite ? "取消收藏" : "收藏", systemImage: item.isFavorite ? "star.slash" : "star")
        }

        Divider()

        Button(role: .destructive) {
            store.delete(item)
            if selectedItemID == item.id {
                selectedItemID = filteredItems.first(where: { $0.id != item.id })?.id
            }
            if previewedItemID == item.id {
                previewedItemID = nil
            }
            NotificationCenter.default.post(name: .hidePastePreview, object: nil)
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Text("wangcl")
                    .font(.headline)
                Spacer()
                Button {
                    store.setPaused(!store.isPaused)
                } label: {
                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                }
                .help(store.isPaused ? "恢复记录：继续保存新的剪切板内容" : "暂停记录：暂时不保存新的剪切板内容")
                .accessibilityLabel(store.isPaused ? "恢复记录" : "暂停记录")
                .buttonStyle(.borderless)
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索文本或 URL", text: $store.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(ClipboardFilter.allCases) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.title)
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selectedFilter == filter ? themeManager.accentColor.opacity(0.22) : Color.secondary.opacity(0.12))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(selectedFilter == filter ? themeManager.accentColor : .clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(selectedFilter == filter ? themeManager.accentColor : .primary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(.bar)
    }

    private var footer: some View {
        HStack {
            Button {
                NotificationCenter.default.post(name: .showPasteSettings, object: nil)
            } label: {
                Image(systemName: "gearshape")
            }
            .help("设置")

            Spacer()

            Button(role: .destructive) {
                store.clearAll()
            } label: {
                Image(systemName: "trash")
            }
            .help("清空")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("退出")
        }
        .buttonStyle(.borderless)
        .padding(12)
        .background(.bar)
    }

    private var filteredItems: [ClipboardItem] {
        store.items.filter { selectedFilter.includes($0) }
    }

    private var selectedItem: ClipboardItem? {
        if let selectedItemID,
           let item = filteredItems.first(where: { $0.id == selectedItemID }) {
            return item
        }
        return filteredItems.first
    }

    private var groupedItems: [ClipboardDateGroup] {
        var groups: [ClipboardDateGroup] = []

        for item in filteredItems {
            let key = Calendar.current.startOfDay(for: item.createdAt)
            if let index = groups.firstIndex(where: { $0.date == key }) {
                groups[index].items.append(item)
            } else {
                groups.append(ClipboardDateGroup(date: key, title: item.createdAt.copyDateGroupTitle, items: [item]))
            }
        }

        return groups
    }

    private func select(_ item: ClipboardItem, updateOpenPreview: Bool = true) {
        selectedItemID = item.id
        clearTextFocus()
        if updateOpenPreview, previewedItemID != nil {
            previewedItemID = item.id
            showPreview(for: item)
        }
    }

    private func togglePreview(for item: ClipboardItem) {
        if previewedItemID == item.id {
            previewedItemID = nil
            NotificationCenter.default.post(name: .hidePastePreview, object: nil)
        } else {
            previewedItemID = item.id
            showPreview(for: item)
        }
    }

    private func showPreview(for item: ClipboardItem) {
        var userInfo: [String: Any] = ["item": item]
        if let rowMidY = rowMidYs[item.id] {
            userInfo["rowMidY"] = rowMidY
        }
        NotificationCenter.default.post(name: .showPastePreview, object: nil, userInfo: userInfo)
    }

    private func installSpacePreviewMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.charactersIgnoringModifiers == " " else {
                return event
            }

            guard selectedItemID != nil || !isTextInputFocused else {
                return event
            }

            guard let item = selectedItem else {
                return event
            }

            selectedItemID = item.id
            clearTextFocus()
            togglePreview(for: item)
            return nil
        }
    }

    private func removeSpacePreviewMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private var isTextInputFocused: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return responder is NSTextView || responder is NSTextField
    }

    private func clearTextFocus() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}

@MainActor
final class ClipboardPreviewModel: ObservableObject {
    @Published var item: ClipboardItem?
    @Published var arrowOffset: CGFloat = 0

    func setItem(_ item: ClipboardItem, arrowOffset: CGFloat) {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            self.item = item
            self.arrowOffset = arrowOffset
        }
    }

    func clear() {
        item = nil
    }
}

struct ClipboardPreviewBubble: View {
    @ObservedObject var model: ClipboardPreviewModel
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.38), radius: 24, x: 0, y: 18)

            PreviewPointer()
                .fill(.ultraThinMaterial)
                .frame(width: 18, height: 32)
                .offset(x: 13, y: model.arrowOffset)

            VStack(spacing: 14) {
                if let item = model.item {
                    previewBody(for: item)
                        .id(item.id)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .padding(18)
        }
    }

    private func previewBody(for item: ClipboardItem) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ClipboardPreviewView(item: item)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.detailText)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(metaText(for: item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.borderless)
                .help("关闭")
            }

            Divider()
                .opacity(0.45)

            previewContent(for: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func previewContent(for item: ClipboardItem) -> some View {
        switch item.type {
        case .image:
            if let path = item.imagePath, let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 338, maxHeight: 397)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
            } else {
                emptyPreview("图片文件不存在")
            }
        case .url:
            ScrollView {
                Text(item.content ?? item.preview)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .textSelection(.enabled)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .file:
            ScrollView {
                Text(item.filePath ?? item.content ?? item.preview)
                    .font(.system(size: 16, design: .monospaced))
                    .textSelection(.enabled)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .text:
            ScrollView {
                Text(item.content ?? item.preview)
                    .font(.system(size: item.isCodeLike ? 15 : 20, weight: item.isCodeLike ? .regular : .semibold, design: item.isCodeLike ? .monospaced : .rounded))
                    .textSelection(.enabled)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func metaText(for item: ClipboardItem) -> String {
        let app = item.sourceApp?.isEmpty == false ? item.sourceApp! : "未知来源"
        return "\(app) · \(previewTimeText(for: item))"
    }

    private func previewTimeText(for item: ClipboardItem) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: item.createdAt)
    }

    private func emptyPreview(_ text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
            Text(text)
                .font(.callout)
        }
        .foregroundStyle(.secondary)
    }
}

private struct RowMidYReader: View {
    let onChange: (CGFloat) -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    onChange(proxy.frame(in: .global).midY)
                }
                .onChange(of: proxy.frame(in: .global).midY) { value in
                    onChange(value)
                }
        }
    }
}

private struct PreviewPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct ClipboardPreviewSheet: View {
    let item: ClipboardItem
    let store: ClipboardStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ClipboardPreviewView(item: item)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.type.displayName)
                        .font(.headline)
                    Text(metaText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.restore(item)
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("关闭")
            }
            .padding(18)
            .background(.bar)

            Divider()

            previewContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(18)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var previewContent: some View {
        switch item.type {
        case .image:
            if let path = item.imagePath, let image = NSImage(contentsOfFile: path) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 520, maxHeight: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                emptyPreview("图片文件不存在")
            }
        case .url:
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.content ?? item.preview)
                        .font(.system(size: 15, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let content = item.content, let url = URL(string: content) {
                        Link(destination: url) {
                            Label("在浏览器中打开", systemImage: "safari")
                        }
                    }
                }
            }
        case .file:
            ScrollView {
                Text(item.filePath ?? item.content ?? item.preview)
                    .font(.system(size: 15, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .text:
            ScrollView {
                Text(item.content ?? item.preview)
                    .font(.system(size: 14, design: item.isCodeLike ? .monospaced : .default))
                    .textSelection(.enabled)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var metaText: String {
        let app = item.sourceApp?.isEmpty == false ? item.sourceApp! : "未知来源"
        return "\(app) · \(previewTimeText)"
    }

    private var previewTimeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: item.createdAt)
    }

    private func emptyPreview(_ text: String) -> some View {
        EmptyStateView(text: text, systemImage: "exclamationmark.triangle")
    }
}

private struct EmptyStateView: View {
    let text: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 32, weight: .medium))
            Text(text)
                .font(.callout)
        }
        .foregroundStyle(.secondary)
    }
}

private enum ClipboardFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case image
    case url
    case code
    case favorite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .text: return "文本"
        case .image: return "图片"
        case .url: return "URL"
        case .code: return "代码"
        case .favorite: return "收藏"
        }
    }

    func includes(_ item: ClipboardItem) -> Bool {
        switch self {
        case .all:
            return true
        case .text:
            return item.type == .text
        case .image:
            return item.type == .image
        case .url:
            return item.type == .url
        case .code:
            return item.isCodeLike
        case .favorite:
            return item.isFavorite
        }
    }
}

private struct ClipboardDateGroup: Identifiable {
    let date: Date
    let title: String
    var items: [ClipboardItem]

    var id: Date { date }
}

private extension ClipboardItem {
    var isCodeLike: Bool {
        guard type == .text, let content else { return false }
        let markers = ["```", "func ", "class ", "struct ", "import ", "let ", "var ", "const ", "=>", "</", "{", "}", "SELECT ", "#include", "def "]
        return markers.contains { content.localizedCaseInsensitiveContains($0) }
    }
}

private extension Date {
    var copyDateGroupTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "今天"
        }
        if calendar.isDateInYesterday(self) {
            return "昨天"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: self)
    }
}
