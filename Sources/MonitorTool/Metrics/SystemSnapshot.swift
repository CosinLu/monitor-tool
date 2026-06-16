import Foundation

struct SystemSnapshot: Identifiable {
    let id = UUID()
    let cpu: CPUStatus
    let memory: MemoryStatus
    let battery: BatteryStatus?
    let thermal: ThermalStatus
    let sampledAt: Date
}

struct CPUStatus {
    let usagePercent: Double
    let userPercent: Double
    let systemPercent: Double
    let idlePercent: Double
}

struct MemoryStatus {
    let totalBytes: UInt64
    let usedBytes: UInt64
    let availableBytes: UInt64
    let pressure: MemoryPressure

    var usedPercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}

enum MemoryPressure: String {
    case normal
    case elevated
    case high

    var localizedDescription: String {
        switch self {
        case .normal: return "正常"
        case .elevated: return "偏高"
        case .high: return "高"
        }
    }
}

struct BatteryStatus {
    let percentage: Int
    let isCharging: Bool
    let isPluggedIn: Bool
    let timeRemainingMinutes: Int?
    let isLowPowerModeEnabled: Bool
}

struct ThermalStatus {
    let state: ThermalState
    let sensorTemperatureCelsius: Double?
    let sensorSource: String?
    let sensorStatus: ThermalSensorStatus
}

enum ThermalSensorStatus {
    case disabled
    case available
    case unavailable
}

enum ThermalState: String {
    case nominal
    case fair
    case serious
    case critical

    var localizedDescription: String {
        switch self {
        case .nominal: return "正常"
        case .fair: return "略热"
        case .serious: return "偏热"
        case .critical: return "过热"
        }
    }
}
