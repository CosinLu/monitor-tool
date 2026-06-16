import Cocoa
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let settingsStore: SettingsStore
    private let sampler: MetricsSampler
    private var clickMonitor: Any?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        settingsStore = SettingsStore()
        sampler = MetricsSampler(settings: settingsStore)

        super.init()

        configureStatusItem()
        configurePopover()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        let image = NSImage(
            systemSymbolName: "battery.100",
            accessibilityDescription: "System Monitor"
        )
        image?.isTemplate = true
        button.image = image
        button.action = #selector(togglePopover)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 460)
        popover.delegate = self

        let rootView = PopoverRootView()
            .environmentObject(sampler)
            .environmentObject(settingsStore)

        popover.contentViewController = NSHostingController(rootView: rootView)
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        sampler.setPopoverVisible(true)
        startClickMonitor()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func closePopover() {
        stopClickMonitor()
        sampler.setPopoverVisible(false)
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        stopClickMonitor()
        sampler.setPopoverVisible(false)
    }

    private func startClickMonitor() {
        stopClickMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.popover.isShown else { return }

            // If the click is on the status bar button, let the button action handle it.
            if let button = self.statusItem.button,
               let buttonWindow = button.window {
                let buttonFrame = button.convert(button.bounds, to: nil)
                let screenFrame = buttonWindow.convertToScreen(buttonFrame)
                if screenFrame.contains(NSEvent.mouseLocation) {
                    return
                }
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
