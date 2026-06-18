import Cocoa
import SwiftUI

@MainActor
final class ProcessDetailsPanelController: ObservableObject {
    private let sampler: MetricsSampler
    private var panel: NSPanel?

    init(sampler: MetricsSampler) {
        self.sampler = sampler
    }

    func show(sortMode: ProcessSortMode, near parentFrame: NSRect? = nil) {
        sampler.loadProcessDetails(sortMode: sortMode)

        let panel = makePanelIfNeeded()
        if !panel.isVisible {
            position(panel, near: parentFrame)
        }
        panel.orderFrontRegardless()
    }

    func close() {
        panel?.close()
    }

    func contains(_ point: NSPoint) -> Bool {
        guard let panel, panel.isVisible else { return false }
        return panel.frame.contains(point)
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel {
            return panel
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 330, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        let rootView = ProcessDetailsView { [weak self] in
            self?.close()
        }
        .environmentObject(sampler)
        .frame(width: 330, height: 420)

        panel.contentViewController = NSHostingController(rootView: rootView)
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel, near parentFrame: NSRect?) {
        let screenFrame = (parentFrame.flatMap { frame in
            NSScreen.screens.first { $0.visibleFrame.intersects(frame) }
        } ?? NSScreen.main)?.visibleFrame
        let visibleFrame = screenFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let panelSize = panel.frame.size

        let proposedOrigin: NSPoint
        if let parentFrame {
            proposedOrigin = NSPoint(
                x: parentFrame.maxX + 10,
                y: parentFrame.maxY - panelSize.height
            )
        } else {
            proposedOrigin = NSPoint(
                x: visibleFrame.midX - panelSize.width / 2,
                y: visibleFrame.midY - panelSize.height / 2
            )
        }

        let x = min(max(proposedOrigin.x, visibleFrame.minX + 8), visibleFrame.maxX - panelSize.width - 8)
        let y = min(max(proposedOrigin.y, visibleFrame.minY + 8), visibleFrame.maxY - panelSize.height - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
