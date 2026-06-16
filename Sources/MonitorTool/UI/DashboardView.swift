import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var sampler: MetricsSampler
    @EnvironmentObject var settings: SettingsStore
    @Binding var showingSettings: Bool

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useGB, .useMB]
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                statusSummary

                cpuSection
                memorySection
                batteryThermalSection

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
    }

    @ViewBuilder
    private var statusSummary: some View {
        HStack {
            Image(systemName: overallIcon)
                .foregroundColor(overallColor)
            Text(overallText)
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .padding(10)
        .background(overallColor.opacity(0.12))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var cpuSection: some View {
        MetricSectionView(title: "CPU", icon: "cpu", color: .blue) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .lastTextBaseline) {
                    Text(cpuPercentText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Spacer()
                    Text("用户 \(userPercentText) · 系统 \(systemPercentText)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                TrendLineView(values: sampler.cpuHistory, color: cpuTrendColor)
                    .frame(height: 36)
            }
        }
    }

    @ViewBuilder
    private var memorySection: some View {
        MetricSectionView(title: "内存", icon: "memorychip", color: .purple) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(memoryUsedText)
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text(memoryPressureText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(memoryPressureColor)
                }

                ProgressView(value: memoryUsedPercent)
                    .tint(memoryPressureColor)

                HStack {
                    Text("总量 \(memoryTotalText)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("可用 \(memoryAvailableText)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var batteryThermalSection: some View {
        MetricSectionView(title: "电池与温度", icon: "bolt.fill", color: .green) {
            VStack(alignment: .leading, spacing: 6) {
                if let battery = sampler.latestSnapshot?.battery {
                    HStack {
                        Image(systemName: batteryIcon(battery))
                            .foregroundColor(batteryColor(battery))
                        Text("电量")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(battery.percentage)%")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(batteryColor(battery))
                    }

                    HStack {
                        Text("充电状态")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(batteryStatusText(battery))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(batteryStatusColor(battery))
                    }

                    HStack {
                        Text("电源模式")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(powerModeText(battery))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(powerModeColor(battery))
                    }

                    HStack {
                        Text("采样模式")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(settings.refreshRate.localizedDescription)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(refreshRateColor)
                    }

                    if let minutes = battery.timeRemainingMinutes {
                        Text(timeRemainingText(minutes: minutes))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("未检测到电池")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Divider()

                HStack {
                    Text("热状态")
                        .font(.system(size: 12))
                    Spacer()
                    Text(thermalStateText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(thermalColor)
                }

                HStack {
                    Text("传感器温度")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(temperatureText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(temperatureColor)
                }

                HStack {
                    Text("高级温度")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(advancedTemperatureStatusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(advancedTemperatureStatusColor)
                }
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        HStack {
            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()

            if let date = sampler.latestSnapshot?.sampledAt {
                Text("更新于 \(timeFormatter.string(from: date))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("退出")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private var snapshot: SystemSnapshot? { sampler.latestSnapshot }

    private var cpuPercentText: String {
        guard let cpu = snapshot?.cpu else { return "--" }
        return String(format: "%.1f%%", cpu.usagePercent)
    }

    private var userPercentText: String {
        guard let cpu = snapshot?.cpu else { return "--" }
        return String(format: "%.1f%%", cpu.userPercent)
    }

    private var systemPercentText: String {
        guard let cpu = snapshot?.cpu else { return "--" }
        return String(format: "%.1f%%", cpu.systemPercent)
    }

    private var cpuTrendColor: Color {
        guard let cpu = snapshot?.cpu else { return .blue }
        if cpu.usagePercent > 80 { return .red }
        if cpu.usagePercent > 50 { return .yellow }
        return .blue
    }

    private var memoryUsedText: String {
        guard let memory = snapshot?.memory else { return "--" }
        return byteFormatter.string(fromByteCount: Int64(memory.usedBytes))
    }

    private var memoryTotalText: String {
        guard let memory = snapshot?.memory else { return "--" }
        return byteFormatter.string(fromByteCount: Int64(memory.totalBytes))
    }

    private var memoryAvailableText: String {
        guard let memory = snapshot?.memory else { return "--" }
        return byteFormatter.string(fromByteCount: Int64(memory.availableBytes))
    }

    private var memoryUsedPercent: Double {
        snapshot?.memory.usedPercent ?? 0
    }

    private var memoryPressureText: String {
        snapshot?.memory.pressure.localizedDescription ?? "--"
    }

    private var memoryPressureColor: Color {
        switch snapshot?.memory.pressure {
        case .high: return .red
        case .elevated: return .yellow
        default: return .green
        }
    }

    private func batteryIcon(_ battery: BatteryStatus) -> String {
        if battery.isCharging { return "bolt.batteryblock.fill" }
        let level = battery.percentage
        if level <= 10 { return "battery.0" }
        if level <= 30 { return "battery.25" }
        if level <= 60 { return "battery.50" }
        if level <= 90 { return "battery.75" }
        return "battery.100"
    }

    private func batteryColor(_ battery: BatteryStatus) -> Color {
        if battery.isLowPowerModeEnabled { return .yellow }
        if battery.isCharging { return .green }
        if battery.percentage <= 20 { return .red }
        if battery.percentage <= 50 { return .yellow }
        return .green
    }

    private func batteryStatusText(_ battery: BatteryStatus) -> String {
        if battery.isCharging { return "充电中" }
        if battery.isPluggedIn { return "已连接电源" }
        return "使用电池"
    }

    private func batteryStatusColor(_ battery: BatteryStatus) -> Color {
        if battery.isCharging { return .green }
        if battery.isPluggedIn { return .blue }
        return .secondary
    }

    private func powerModeText(_ battery: BatteryStatus) -> String {
        battery.isLowPowerModeEnabled ? "低电量模式" : "标准模式"
    }

    private func powerModeColor(_ battery: BatteryStatus) -> Color {
        battery.isLowPowerModeEnabled ? .yellow : .green
    }

    private var refreshRateColor: Color {
        switch settings.refreshRate {
        case .powerSaving: return .yellow
        case .standard: return .green
        case .realtime: return .blue
        }
    }

    private func timeRemainingText(minutes: Int) -> String {
        if minutes <= 0 { return "计算中…" }
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return "剩余 \(h) 小时 \(m) 分钟"
        } else {
            return "剩余 \(m) 分钟"
        }
    }

    private var thermalStateText: String {
        snapshot?.thermal.state.localizedDescription ?? "--"
    }

    private var thermalColor: Color {
        switch snapshot?.thermal.state {
        case .critical: return .red
        case .serious: return .orange
        case .fair: return .yellow
        default: return .green
        }
    }

    private var temperatureText: String {
        guard let temp = snapshot?.thermal.sensorTemperatureCelsius else {
            return "--°C"
        }
        return String(format: "%.0f°C", temp)
    }

    private var temperatureColor: Color {
        switch snapshot?.thermal.sensorStatus {
        case .available: return thermalColor
        default: return .secondary
        }
    }

    private var advancedTemperatureStatusText: String {
        guard let thermal = snapshot?.thermal else { return "--" }
        switch thermal.sensorStatus {
        case .disabled:
            return "未开启"
        case .available:
            return "读取成功" + (thermal.sensorSource.map { " · \($0)" } ?? "")
        case .unavailable:
            return "读取失败，已降级"
        }
    }

    private var advancedTemperatureStatusColor: Color {
        switch snapshot?.thermal.sensorStatus {
        case .available: return .green
        case .unavailable: return .yellow
        default: return .secondary
        }
    }

    private var overallText: String {
        guard let snapshot = snapshot else { return "正在采集…" }
        if snapshot.thermal.state == .critical || snapshot.thermal.state == .serious {
            return "系统温度偏高"
        }
        if snapshot.memory.pressure == .high {
            return "内存压力较高"
        }
        if snapshot.cpu.usagePercent > 80 {
            return "CPU 负载较高"
        }
        return "系统状态正常"
    }

    private var overallIcon: String {
        switch overallColor {
        case .green: return "checkmark.circle.fill"
        case .yellow: return "exclamationmark.triangle.fill"
        case .red: return "xmark.octagon.fill"
        default: return "info.circle.fill"
        }
    }

    private var overallColor: Color {
        guard let snapshot = snapshot else { return .secondary }
        if snapshot.thermal.state == .critical || snapshot.thermal.state == .serious {
            return .red
        }
        if snapshot.memory.pressure == .high || snapshot.cpu.usagePercent > 80 {
            return .yellow
        }
        return .green
    }

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
