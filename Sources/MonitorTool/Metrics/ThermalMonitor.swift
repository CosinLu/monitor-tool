import Foundation

final class ThermalMonitor: @unchecked Sendable {
    private let smc = SMCMonitor()

    func sample(advanced: Bool) -> ThermalStatus {
        let state = thermalState(from: ProcessInfo.processInfo.thermalState)

        var sensorTemp: Double?
        var source: String?
        var sensorStatus: ThermalSensorStatus = .disabled

        if advanced {
            if let temp = smc.readTemperature() {
                sensorTemp = temp
                source = "SMC"
                sensorStatus = .available
            } else {
                sensorStatus = .unavailable
            }
        }

        return ThermalStatus(
            state: state,
            sensorTemperatureCelsius: sensorTemp,
            sensorSource: source,
            sensorStatus: sensorStatus
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
