import SwiftUI

struct ClipboardPreviewView: View {
    let item: ClipboardItem

    var body: some View {
        ZStack {
            if let icon = sourceAppIcon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .padding(5)
            } else {
                symbol(fallbackSymbol)
            }
        }
        .frame(width: 44, height: 44)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var sourceAppIcon: NSImage? {
        guard let bundleIdentifier = item.sourceBundleIdentifier,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 44, height: 44)
        return icon
    }

    private var fallbackSymbol: String {
        switch item.type {
        case .text:
            return "text.alignleft"
        case .url:
            return "link"
        case .file:
            return "doc"
        case .image:
            return "photo"
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.secondary)
    }
}
