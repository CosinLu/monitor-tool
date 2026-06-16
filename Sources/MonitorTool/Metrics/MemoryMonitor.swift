import Foundation
import MachO

final class MemoryMonitor: @unchecked Sendable {
    private lazy var totalBytes: UInt64 = {
        var size = MemoryLayout<UInt64>.size
        var total: UInt64 = 0
        sysctlbyname("hw.memsize", &total, &size, nil, 0)
        return total
    }()

    func sample() -> MemoryStatus {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryStatus(
                totalBytes: totalBytes,
                usedBytes: 0,
                availableBytes: totalBytes,
                pressure: .normal
            )
        }

        let pageSize = UInt64(getpagesize())

        let free = UInt64(vmStats.free_count) * pageSize
        let active = UInt64(vmStats.active_count) * pageSize
        let inactive = UInt64(vmStats.inactive_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize

        let used = active + wired + compressed
        let available = free + inactive

        let pressure: MemoryPressure
        let usedPercent = Double(used) / Double(totalBytes)
        if usedPercent > 0.85 {
            pressure = .high
        } else if usedPercent > 0.70 {
            pressure = .elevated
        } else {
            pressure = .normal
        }

        return MemoryStatus(
            totalBytes: totalBytes,
            usedBytes: used,
            availableBytes: available,
            pressure: pressure
        )
    }
}
