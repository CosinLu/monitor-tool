import Foundation
import IOKit

final class SMCMonitor: @unchecked Sendable {
    /// Best-effort temperature read for Apple Silicon.
    /// Returns nil when SMC/thermal sensors are not accessible without privileges.
    func readTemperature() -> Double? {
        return readFromIORegistry()
    }

    private func readFromIORegistry() -> Double? {
        let keys = ["TS0P", "TS1P", "TC0P", "TC1C", "TC2C", "TCGC", "TCPP", "TPCD"]

        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:")
        guard entry != MACH_PORT_NULL else { return nil }
        defer { IOObjectRelease(entry) }

        for key in keys {
            if let value = readTemperatureKey(entry: entry, key: key) {
                return value
            }
        }

        return nil
    }

    private func readTemperatureKey(entry: io_registry_entry_t, key: String) -> Double? {
        guard let data = IORegistryEntryCreateCFProperty(
            entry,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Data else {
            return nil
        }

        guard data.count >= 2 else { return nil }

        let upper = data[0]
        let lower = data[1]
        let rawValue = (UInt16(upper) << 8) | UInt16(lower)

        // Apple SMC encodes temperature as signed fixed-point 8.8.
        let temperature = Double(Int16(bitPattern: rawValue)) / 256.0
        guard temperature > -50 && temperature < 150 else { return nil }
        return temperature
    }
}
