import Foundation

final class PowermetricsTemperatureMonitor: @unchecked Sendable {
    private let minimumInterval: TimeInterval = 60
    private let timeout: TimeInterval = 4
    private var lastAttempt: Date?
    private var cachedReading: TemperatureReading?

    func readTemperatureIfDue() -> TemperatureReading? {
        let now = Date()
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < minimumInterval {
            return cachedReading
        }

        lastAttempt = now
        cachedReading = readTemperature()
        return cachedReading
    }

    func readTemperatureWithAuthorization() -> TemperatureReading? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            #"do shell script "/usr/bin/powermetrics --samplers thermal -n 1 -i 1000" with administrator privileges"#
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return nil
        }

        let killer = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 30, execute: killer)

        process.waitUntilExit()
        killer.cancel()

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }

        cachedReading = parseTemperature(from: output)
        lastAttempt = Date()
        return cachedReading
    }

    private func readTemperature() -> TemperatureReading? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = [
            "-n",
            "/usr/bin/powermetrics",
            "--samplers",
            "thermal",
            "-n",
            "1",
            "-i",
            "1000"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return nil
        }

        let killer = DispatchWorkItem {
            if process.isRunning {
                process.terminate()
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: killer)

        process.waitUntilExit()
        killer.cancel()

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }

        return parseTemperature(from: output)
    }

    private func parseTemperature(from output: String) -> TemperatureReading? {
        let patterns = [
            #"(?i)(?:temperature|temp)[^0-9\-]{0,40}([0-9]+(?:\.[0-9]+)?)\s*(?:C|℃|celsius)"#,
            #"(?i)([0-9]+(?:\.[0-9]+)?)\s*(?:C|℃|celsius)[^\n]{0,40}(?:temperature|temp)"#
        ]

        let values = patterns.flatMap { pattern -> [Double] in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            return regex.matches(in: output, range: range).compactMap { match in
                guard let valueRange = Range(match.range(at: 1), in: output) else { return nil }
                let value = Double(output[valueRange])
                guard let value, value > 0, value < 130 else { return nil }
                return value
            }
        }

        guard !values.isEmpty else { return nil }
        let average = values.reduce(0, +) / Double(values.count)
        return TemperatureReading(
            averageCelsius: average,
            minimumCelsius: values.min() ?? average,
            maximumCelsius: values.max() ?? average,
            source: "powermetrics",
            sensorCount: values.count
        )
    }
}
