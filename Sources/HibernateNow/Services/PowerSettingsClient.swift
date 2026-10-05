import Foundation

struct PowerSettingsClient {
    func read() throws -> PowerSnapshot {
        try PowerSnapshot.parse(
            live: runPMSet(["-g"]),
            custom: runPMSet(["-g", "custom"]),
            source: runPMSet(["-g", "ps"])
        )
    }

    private func runPMSet(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            let detail = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw PowerError.commandFailed(detail.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return text
    }
}
