import AppKit
import Foundation

final class ClipboardWatcher {
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private let onChange: (NSPasteboard) -> Void

    init(onChange: @escaping (NSPasteboard) -> Void) {
        self.onChange = onChange
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self else { return }
            let pasteboard = NSPasteboard.general
            guard pasteboard.changeCount != self.lastChangeCount else { return }
            self.lastChangeCount = pasteboard.changeCount
            self.onChange(pasteboard)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func markCurrentPasteboardAsHandled() {
        lastChangeCount = NSPasteboard.general.changeCount
    }
}
