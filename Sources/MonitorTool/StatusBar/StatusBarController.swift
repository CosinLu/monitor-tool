import Cocoa
import SwiftUI
import Combine

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let settingsStore: SettingsStore
    private let sampler: MetricsSampler
    private var clickMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        settingsStore = SettingsStore()
        sampler = MetricsSampler(settings: settingsStore)

        super.init()

        configureStatusItem()
        configurePopover()
        subscribeToBatteryUpdates()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        updateMenuBarIcon(battery: nil)
        button.action = #selector(togglePopover)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func subscribeToBatteryUpdates() {
        sampler.$latestSnapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.updateMenuBarIcon(battery: snapshot?.battery)
            }
            .store(in: &cancellables)
    }

    private func updateMenuBarIcon(battery: BatteryStatus?) {
        guard let button = statusItem.button else { return }

        let symbolName: String
        if let battery = battery {
            let level = battery.percentage
            let charging = battery.isCharging

            switch level {
            case 0...10:
                symbolName = charging ? "battery.0bolt" : "battery.0"
            case 11...30:
                symbolName = charging ? "battery.25bolt" : "battery.25"
            case 31...60:
                symbolName = charging ? "battery.50bolt" : "battery.50"
            case 61...90:
                symbolName = charging ? "battery.75bolt" : "battery.75"
            default:
                symbolName = charging ? "battery.100bolt" : "battery.100"
            }
        } else {
            symbolName = "battery.100"
        }

        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "System Monitor"
        )
        image?.isTemplate = true
        button.image = image
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
