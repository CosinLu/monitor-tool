import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Text("设置")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                // Invisible spacer to balance the back button.
                Image(systemName: "chevron.left")
                    .font(.system(size: 14))
                    .opacity(0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            Form {
                Section {
                    Picker("刷新频率", selection: $settings.refreshRate) {
                        ForEach(RefreshRate.allCases) { rate in
                            Text(rate.localizedDescription).tag(rate)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("弹窗关闭后: \(Int(settings.refreshRate.popoverClosedInterval)) 秒 · 弹窗打开后: \(String(format: "%.1f", settings.refreshRate.popoverOpenInterval)) 秒")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } header: {
                    Text("采样")
                        .font(.system(size: 11, weight: .medium))
                }

                Section {
                    Toggle("高级温度模式", isOn: $settings.advancedTemperature)
                    Text("开启后尝试读取 SMC 传感器，失败时自动降级为系统热状态。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } header: {
                    Text("温度")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .formStyle(.grouped)

            Spacer()
        }
    }
}
