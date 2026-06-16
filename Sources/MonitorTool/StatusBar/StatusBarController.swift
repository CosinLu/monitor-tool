import Cocoa
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let settingsStore: SettingsStore
    private let sampler: MetricsSampler

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
            systemSymbolName: "waveform.path.ecg",
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
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func closePopover() {
        sampler.setPopoverVisible(false)
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        sampler.setPopoverVisible(false)
    }
}
