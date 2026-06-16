import Foundation
import Combine

enum RefreshRate: String, CaseIterable, Identifiable {
    case powerSaving
    case standard
    case realtime

    var id: String { rawValue }

    var localizedDescription: String {
        switch self {
        case .powerSaving: return "省电"
        case .standard: return "标准"
        case .realtime: return "实时"
        }
    }

    var popoverClosedInterval: TimeInterval {
        switch self {
        case .powerSaving: return 15
        case .standard: return 8
        case .realtime: return 5
        }
    }

    var popoverOpenInterval: TimeInterval {
        switch self {
        case .powerSaving: return 2
        case .standard: return 1
        case .realtime: return 0.5
        }
    }
}

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let refreshRate = "refreshRate"
        static let advancedTemperature = "advancedTemperature"
    }

    @Published var refreshRate: RefreshRate {
        didSet {
            UserDefaults.standard.set(refreshRate.rawValue, forKey: Keys.refreshRate)
        }
    }

    @Published var advancedTemperature: Bool {
        didSet {
            UserDefaults.standard.set(advancedTemperature, forKey: Keys.advancedTemperature)
        }
    }

    init() {
        let defaults = UserDefaults.standard

        let savedRate = defaults.string(forKey: Keys.refreshRate) ?? ""
        self.refreshRate = RefreshRate(rawValue: savedRate) ?? .standard

        self.advancedTemperature = defaults.object(forKey: Keys.advancedTemperature) as? Bool ?? false
    }
}
