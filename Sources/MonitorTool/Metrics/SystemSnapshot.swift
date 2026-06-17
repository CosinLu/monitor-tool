import Foundation

struct SystemSnapshot: Identifiable {
    let id = UUID()
    let cpu: CPUStatus
    let memory: MemoryStatus
    let battery: BatteryStatus?
    let thermal: ThermalStatus
    let appResource: AppResourceStatus
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
    let averageTemperatureCelsius: Double?
    let minimumTemperatureCelsius: Double?
    let maximumTemperatureCelsius: Double?
    let temperatureSource: String?
    let temperatureSensorCount: Int
    let temperatureStatus: TemperatureStatus
    let temperatureSampledAt: Date?
}

struct TemperatureReading {
    let averageCelsius: Double
    let minimumCelsius: Double
    let maximumCelsius: Double
    let source: String
    let sensorCount: Int
}

enum TemperatureStatus {
    case available
    case needsPermission
    case unavailable
}

struct AppResourceStatus {
    let cpuUsagePercent: Double
    let memoryBytes: UInt64
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
