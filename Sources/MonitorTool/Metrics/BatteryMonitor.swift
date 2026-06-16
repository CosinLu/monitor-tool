import Foundation
import IOKit.ps

final class BatteryMonitor: @unchecked Sendable {
    func sample() -> BatteryStatus? {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first else {
            return nil
        }

        let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
        guard let info = info else { return nil }

        let current = info[kIOPSCurrentCapacityKey] as? Int ?? 0
        let max = info[kIOPSMaxCapacityKey] as? Int ?? 100
        let percentage = max > 0 ? (current * 100 / max) : 0

        let isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
        let powerSourceState = info[kIOPSPowerSourceStateKey] as? String
        let isPluggedIn = powerSourceState == kIOPSACPowerValue

        var timeRemaining: Int?
        if isCharging {
            timeRemaining = info[kIOPSTimeToFullChargeKey] as? Int
        } else {
            timeRemaining = info[kIOPSTimeToEmptyKey] as? Int
        }

        if let time = timeRemaining, time < 0 {
            timeRemaining = nil
        }

        return BatteryStatus(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            timeRemainingMinutes: timeRemaining,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
}
