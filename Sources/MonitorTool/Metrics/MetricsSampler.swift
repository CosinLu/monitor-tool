import Foundation
import Combine
import Cocoa

@MainActor
final class MetricsSampler: ObservableObject {
    @Published private(set) var latestSnapshot: SystemSnapshot?
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var isAuthorizingTemperature = false

    private let settings: SettingsStore
    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let batteryMonitor = BatteryMonitor()
    private let thermalMonitor = ThermalMonitor()
    private let appResourceMonitor = AppResourceMonitor()

    private var timer: Timer?
    private var isPopoverVisible = false
    private var isAsleep = false
    private var cancellables = Set<AnyCancellable>()

    private let sampleQueue = DispatchQueue(label: "com.example.MonitorTool.sample", qos: .utility)
    private let historyCapacity = 60

    init(settings: SettingsStore) {
        self.settings = settings
        setupNotifications()
        setupSettingsSubscriptions()
        updateTimer()
        sample()
    }

    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func setPopoverVisible(_ visible: Bool) {
        guard isPopoverVisible != visible else { return }
        isPopoverVisible = visible
        updateTimer()
        if visible {
            sample()
        }
    }

    func refreshTemperatureWithAuthorization() {
        guard !isAuthorizingTemperature else { return }
        isAuthorizingTemperature = true

        let thermalMonitor = self.thermalMonitor
        sampleQueue.async { [weak self] in
            let thermal = thermalMonitor.sampleWithAuthorization()

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let snapshot = self.latestSnapshot {
                    self.latestSnapshot = SystemSnapshot(
                        cpu: snapshot.cpu,
                        memory: snapshot.memory,
                        battery: snapshot.battery,
                        thermal: thermal,
                        appResource: snapshot.appResource,
                        sampledAt: Date()
                    )
                }
                self.isAuthorizingTemperature = false
            }
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    private func setupSettingsSubscriptions() {
        settings.$refreshRate
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTimer()
            }
            .store(in: &cancellables)
    }

    @objc private func systemWillSleep() {
        isAsleep = true
        updateTimer()
    }

    @objc private func systemDidWake() {
        isAsleep = false
        updateTimer()
        sample()
    }

    private func updateTimer() {
        timer?.invalidate()
        timer = nil

        guard !isAsleep else { return }

        let interval: TimeInterval
        if isPopoverVisible {
            interval = settings.refreshRate.popoverOpenInterval
        } else {
            interval = settings.refreshRate.popoverClosedInterval
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sample()
            }
        }
    }

    private func sample() {
        let cpuMonitor = self.cpuMonitor
        let memoryMonitor = self.memoryMonitor
        let batteryMonitor = self.batteryMonitor
        let thermalMonitor = self.thermalMonitor
        let appResourceMonitor = self.appResourceMonitor
        let capacity = historyCapacity

        sampleQueue.async { [weak self] in
            let cpu = cpuMonitor.sample()
            let memory = memoryMonitor.sample()
            let battery = batteryMonitor.sample()
            let thermal = thermalMonitor.sample()
            let appResource = appResourceMonitor.sample()

            let snapshot = SystemSnapshot(
                cpu: cpu,
                memory: memory,
                battery: battery,
                thermal: thermal,
                appResource: appResource,
                sampledAt: Date()
            )

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.latestSnapshot = snapshot
                self.cpuHistory.append(cpu.usagePercent)
                if self.cpuHistory.count > capacity {
                    self.cpuHistory.removeFirst(self.cpuHistory.count - capacity)
                }
            }
        }
    }
}
