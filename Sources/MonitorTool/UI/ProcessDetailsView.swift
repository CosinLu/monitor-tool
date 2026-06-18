import SwiftUI

struct ProcessDetailsView: View {
    @EnvironmentObject var sampler: MetricsSampler
    let onClose: () -> Void

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            header

            if sampler.isLoadingProcessDetails {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sampler.processDetails.isEmpty {
                Text("暂无进程数据")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                processList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .onDisappear {
            sampler.clearProcessDetails()
        }
    }

    private var header: some View {
        HStack {
            ZStack {
                WindowDragHandle()
                    .frame(height: 52)

                HStack(spacing: 9) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.32))
                        .frame(width: 4, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                        Text("按需采样，关闭后不持续读取")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 52)

            Spacer()

            Button {
                if let mode = sampler.processDetailMode {
                    sampler.loadProcessDetails(sortMode: mode)
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .disabled(sampler.isLoadingProcessDetails)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var processList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("进程")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("PID")
                    .frame(width: 46, alignment: .trailing)
                Text("CPU")
                    .frame(width: 52, alignment: .trailing)
                Text("内存")
                    .frame(width: 72, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sampler.processDetails) { process in
                        processRow(process)
                        Divider()
                            .padding(.leading, 14)
                    }
                }
            }
        }
    }

    private func processRow(_ process: ProcessStatus) -> some View {
        HStack(spacing: 10) {
            Text(process.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(process.pid)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 46, alignment: .trailing)

            Text(String(format: "%.1f%%", process.cpuPercent))
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 52, alignment: .trailing)

            Text(byteFormatter.string(fromByteCount: Int64(process.memoryBytes)))
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var title: String {
        switch sampler.processDetailMode {
        case .cpu: return "CPU 占用详情"
        case .memory: return "内存占用详情"
        case .none: return "进程详情"
        }
    }
}
