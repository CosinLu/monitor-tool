import Foundation
import MachO

final class CPUMonitor: @unchecked Sendable {
    private var previousTicks: cpu_ticks?

    func sample() -> CPUStatus {
        var processorCount: natural_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS,
              let info = processorInfo else {
            return CPUStatus(usagePercent: 0, userPercent: 0, systemPercent: 0, idlePercent: 100)
        }

        defer {
            let size = vm_size_t(processorInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0

        for i in 0..<Int(processorCount) {
            let base = i * Int(CPU_STATE_MAX)
            totalUser += UInt64(info[base + Int(CPU_STATE_USER)])
            totalSystem += UInt64(info[base + Int(CPU_STATE_SYSTEM)])
            totalIdle += UInt64(info[base + Int(CPU_STATE_IDLE)])
            totalNice += UInt64(info[base + Int(CPU_STATE_NICE)])
        }

        let currentTicks = cpu_ticks(
            user: totalUser,
            system: totalSystem,
            idle: totalIdle,
            nice: totalNice
        )

        defer { previousTicks = currentTicks }

        guard let previous = previousTicks else {
            return CPUStatus(usagePercent: 0, userPercent: 0, systemPercent: 0, idlePercent: 100)
        }

        let userDelta = currentTicks.user - previous.user
        let systemDelta = currentTicks.system - previous.system
        let idleDelta = currentTicks.idle - previous.idle
        let niceDelta = currentTicks.nice - previous.nice

        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
        guard totalDelta > 0 else {
            return CPUStatus(usagePercent: 0, userPercent: 0, systemPercent: 0, idlePercent: 100)
        }

        let usage = Double(totalDelta - idleDelta) / Double(totalDelta)
        let user = Double(userDelta + niceDelta) / Double(totalDelta)
        let system = Double(systemDelta) / Double(totalDelta)
        let idle = Double(idleDelta) / Double(totalDelta)

        return CPUStatus(
            usagePercent: usage * 100,
            userPercent: user * 100,
            systemPercent: system * 100,
            idlePercent: idle * 100
        )
    }
}

private struct cpu_ticks {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64
}
