import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let settingsManager = SettingsManager()
    let themeManager: ThemeManager
    let store: ClipboardStore

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var eventMonitor: Any?
    private var settingsWindow: NSWindow?
    private var previewPanel: NSPanel?
    private let previewModel = ClipboardPreviewModel()

    override init() {
        self.themeManager = ThemeManager(settingsManager: settingsManager)
        self.store = ClipboardStore(settingsManager: settingsManager)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        setupNotifications()
        applyAppearance()
        themeManager.onAppearanceChanged = { [weak self] in self?.applyAppearance() }
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        hidePreviewPanel()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "wangcl")
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 357, height: 620)
        popover.contentViewController = NSHostingController(
            rootView: ClipboardListView(store: store, themeManager: themeManager)
        )

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover.performClose(nil)
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowSettingsNotification),
            name: .showPasteSettings,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowPreviewNotification(_:)),
            name: .showPastePreview,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHidePreviewNotification),
            name: .hidePastePreview,
            object: nil
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func handleShowSettingsNotification() {
        showSettingsWindow()
    }

    @objc private func handleShowPreviewNotification(_ notification: Notification) {
        guard let item = notification.userInfo?["item"] as? ClipboardItem else { return }
        let rowMidY = notification.userInfo?["rowMidY"] as? CGFloat
        showPreviewPanel(for: item, rowMidY: rowMidY)
    }

    @objc private func handleHidePreviewNotification() {
        hidePreviewPanel()
    }

    private func applyAppearance() {
        switch themeManager.appearanceMode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func showSettingsWindow() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSHostingController(
            rootView: SettingsView(
                store: store,
                themeManager: themeManager,
                settingsManager: settingsManager
            )
        )
        let window = NSWindow(contentViewController: controller)
        window.title = "wangcl 设置"
        window.setContentSize(NSSize(width: 520, height: 520))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showPreviewPanel(for item: ClipboardItem, rowMidY: CGFloat?) {
        let panelSize = NSSize(width: 408, height: 520)

        let panel = previewPanel ?? NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        if previewPanel == nil {
            panel.contentViewController = NSHostingController(
                rootView: ClipboardPreviewBubble(model: previewModel) { [weak self] in
                    Task { @MainActor in self?.hidePreviewPanel() }
                }
            )
        }
        panel.setContentSize(panelSize)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.transient, .ignoresCycle]

        var arrowOffset: CGFloat = 0
        if let popoverWindow = popover.contentViewController?.view.window {
            let popoverFrame = popoverWindow.frame
            let x = max(12, popoverFrame.minX - panelSize.width - 12)
            let rowScreenY: CGFloat
            if let rowMidY {
                rowScreenY = popoverFrame.maxY - rowMidY
            } else {
                rowScreenY = popoverFrame.maxY - 245
            }

            let desiredY = rowScreenY - panelSize.height / 2
            let minY: CGFloat = 12
            let maxY = max(minY, popoverFrame.maxY - panelSize.height - 12)
            let clampedY = min(max(desiredY, minY), maxY)
            arrowOffset = min(max(rowScreenY - (clampedY + panelSize.height / 2), -196), 196)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = panel.isVisible ? 0.18 : 0
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrameOrigin(NSPoint(x: x, y: clampedY))
            }
        }

        previewPanel = panel
        previewModel.setItem(item, arrowOffset: arrowOffset)

        if panel.isVisible {
            panel.orderFrontRegardless()
        } else {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }
    }

    private func hidePreviewPanel() {
        guard let previewPanel, previewPanel.isVisible else {
            previewModel.clear()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            previewPanel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                self?.previewPanel?.orderOut(nil)
                self?.previewPanel?.alphaValue = 1
                self?.previewModel.clear()
            }
        }
    }
}

extension Notification.Name {
    static let showPasteSettings = Notification.Name("showPasteSettings")
    static let showPastePreview = Notification.Name("showPastePreview")
    static let hidePastePreview = Notification.Name("hidePastePreview")
}
