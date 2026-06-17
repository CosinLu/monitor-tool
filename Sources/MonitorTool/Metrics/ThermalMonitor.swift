import Foundation

final class ThermalMonitor: @unchecked Sendable {
    private let temperatureMonitor = HIDTemperatureMonitor()
    private let powermetricsMonitor = PowermetricsTemperatureMonitor()

    func sample() -> ThermalStatus {
        let state = thermalState(from: ProcessInfo.processInfo.thermalState)
        let reading = temperatureMonitor.readTemperature()
            ?? powermetricsMonitor.readTemperatureIfDue()

        return status(from: state, reading: reading)
    }

    func sampleWithAuthorization() -> ThermalStatus {
        let state = thermalState(from: ProcessInfo.processInfo.thermalState)
        let reading = temperatureMonitor.readTemperature()
            ?? powermetricsMonitor.readTemperatureWithAuthorization()

        return status(from: state, reading: reading)
    }

    private func status(from state: ThermalState, reading: TemperatureReading?) -> ThermalStatus {
        return ThermalStatus(
            state: state,
            averageTemperatureCelsius: reading?.averageCelsius,
            minimumTemperatureCelsius: reading?.minimumCelsius,
            maximumTemperatureCelsius: reading?.maximumCelsius,
            temperatureSource: reading?.source,
            temperatureSensorCount: reading?.sensorCount ?? 0,
            temperatureStatus: reading == nil ? .needsPermission : .available,
            temperatureSampledAt: reading == nil ? nil : Date()
        )
    }

    private func thermalState(from state: ProcessInfo.ThermalState) -> ThermalState {
        switch state {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }
}
