import Foundation

enum ProcessSortMode {
    case cpu
    case memory
}

struct ProcessStatus: Identifiable {
    let id: Int
    let pid: Int
    let name: String
    let cpuPercent: Double
    let memoryBytes: UInt64
}

final class ProcessMonitor: @unchecked Sendable {
    func sample(sortMode: ProcessSortMode, limit: Int = 12) -> [ProcessStatus] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = [
            sortMode == .cpu ? "-arcxo" : "-amxo",
            "pid=,pcpu=,rss=,comm="
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return [] }
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        return output
            .split(separator: "\n")
            .lazy
            .compactMap(parseLine)
            .prefix(limit)
            .map { $0 }
    }

    private func parseLine(_ line: Substring) -> ProcessStatus? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
        guard parts.count == 4,
              let pid = Int(parts[0]),
              let cpu = Double(parts[1]),
              let rssKilobytes = UInt64(parts[2]) else {
            return nil
        }

        return ProcessStatus(
            id: pid,
            pid: pid,
            name: displayName(from: String(parts[3])),
            cpuPercent: cpu,
            memoryBytes: rssKilobytes * 1024
        )
    }

    private func displayName(from command: String) -> String {
        let url = URL(fileURLWithPath: command)
        let lastPathComponent = url.lastPathComponent
        return lastPathComponent.isEmpty ? command : lastPathComponent
    }
}
