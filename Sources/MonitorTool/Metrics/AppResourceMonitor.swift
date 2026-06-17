import Foundation
import MachO

final class AppResourceMonitor: @unchecked Sendable {
    private var previousCPUTime: TimeInterval?
    private var previousUptime: TimeInterval?

    func sample() -> AppResourceStatus {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)

        let currentCPUTime = timeInterval(from: usage.ru_utime) + timeInterval(from: usage.ru_stime)
        let currentUptime = ProcessInfo.processInfo.systemUptime

        let cpuPercent: Double
        if let previousCPUTime, let previousUptime {
            let cpuDelta = currentCPUTime - previousCPUTime
            let uptimeDelta = currentUptime - previousUptime
            cpuPercent = uptimeDelta > 0 ? max(0, cpuDelta / uptimeDelta * 100) : 0
        } else {
            cpuPercent = 0
        }

        previousCPUTime = currentCPUTime
        previousUptime = currentUptime

        return AppResourceStatus(
            cpuUsagePercent: cpuPercent,
            memoryBytes: currentMemoryBytes()
        )
    }

    private func timeInterval(from value: timeval) -> TimeInterval {
        TimeInterval(value.tv_sec) + TimeInterval(value.tv_usec) / 1_000_000
    }

    private func currentMemoryBytes() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.phys_footprint)
    }
}
