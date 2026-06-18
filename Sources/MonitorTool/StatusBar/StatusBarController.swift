import Cocoa
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSWindowDelegate {
    private var statusItem: NSStatusItem
    private var panel: NSPanel
    private let settingsStore: SettingsStore
    private let sampler: MetricsSampler
    private var clickMonitor: Any?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 460),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        settingsStore = SettingsStore()
        sampler = MetricsSampler(settings: settingsStore)

        super.init()

        configureStatusItem()
        configurePanel()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        let image = NSImage(
            systemSymbolName: "waveform.path.ecg",
            accessibilityDescription: "System Monitor"
        )
        image?.isTemplate = true
        button.image = image
        button.action = #selector(togglePopover)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePanel() {
        panel.delegate = self
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.backgroundColor = .clear
        panel.isOpaque = false

        let rootView = PopoverRootView()
            .environmentObject(sampler)
            .environmentObject(settingsStore)

        panel.contentViewController = NSHostingController(rootView: rootView)
    }

    @objc private func togglePopover() {
        if panel.isVisible {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        sampler.setPopoverVisible(true)
        startClickMonitor()

        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = button.window?.convertToScreen(buttonFrame) ?? .zero
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.minY - panelSize.height - 8
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()
    }

    private func closePopover() {
        stopClickMonitor()
        sampler.setPopoverVisible(false)
        panel.close()
    }

    func windowWillClose(_ notification: Notification) {
        stopClickMonitor()
        sampler.setPopoverVisible(false)
    }

    private func startClickMonitor() {
        stopClickMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.panel.isVisible else { return }

            // If the click is on the status bar button, let the button action handle it.
            if let button = self.statusItem.button,
               let buttonWindow = button.window {
                let buttonFrame = button.convert(button.bounds, to: nil)
                let screenFrame = buttonWindow.convertToScreen(buttonFrame)
                if screenFrame.contains(NSEvent.mouseLocation) {
                    return
                }
            }

            if self.panel.frame.contains(NSEvent.mouseLocation) {
                return
            }

            self.closePopover()
        }
    }

    private func stopClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
}
