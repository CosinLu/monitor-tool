import CoreFoundation
import Foundation
import IOKit

typealias IOHIDEventSystemClient = CFTypeRef
typealias IOHIDServiceClient = CFTypeRef
typealias IOHIDEvent = CFTypeRef

@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> IOHIDEventSystemClient?

@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatching(
    _ client: IOHIDEventSystemClient,
    _ matching: CFDictionary
)

@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ client: IOHIDEventSystemClient) -> CFArray?

@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(
    _ service: IOHIDServiceClient,
    _ type: Int64,
    _ options: Int32,
    _ timestamp: Int64
) -> IOHIDEvent?

@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ event: IOHIDEvent, _ field: Int32) -> Double

final class HIDTemperatureMonitor: @unchecked Sendable {
    private enum HID {
        static let eventTypeTemperature: Int64 = 15
        static let temperatureField: Int32 = Int32((15 << 16) | 0)
        static let appleVendorUsagePage = 0xff00
        static let temperatureSensorUsage = 5
    }

    func readTemperature() -> TemperatureReading? {
        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else {
            return nil
        }

        let matching: [String: Any] = [
            "PrimaryUsagePage": HID.appleVendorUsagePage,
            "PrimaryUsage": HID.temperatureSensorUsage
        ]
        IOHIDEventSystemClientSetMatching(client, matching as CFDictionary)

        guard let services = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] else {
            return nil
        }

        let temperatures = services.compactMap { service -> Double? in
            guard let event = IOHIDServiceClientCopyEvent(
                service,
                HID.eventTypeTemperature,
                0,
                0
            ) else {
                return nil
            }

            let celsius = IOHIDEventGetFloatValue(event, HID.temperatureField)
            guard celsius > 0, celsius < 130 else { return nil }
            return celsius
        }

        guard !temperatures.isEmpty else { return nil }
        let average = temperatures.reduce(0, +) / Double(temperatures.count)
        return TemperatureReading(
            averageCelsius: average,
            minimumCelsius: temperatures.min() ?? average,
            maximumCelsius: temperatures.max() ?? average,
            source: "Apple Silicon HID",
            sensorCount: temperatures.count
        )
    }
}
