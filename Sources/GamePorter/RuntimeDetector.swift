import Foundation

struct RuntimeInfo {
    let name: String
    let executable: String
    let version: String?
}

enum RuntimeDetector {
    static func detect() -> [RuntimeInfo] {
        let candidates = [
            ("Wine (Homebrew)", "/opt/homebrew/bin/wine64"),
            ("Wine (Intel Homebrew)", "/usr/local/bin/wine64"),
            ("Wine", "/usr/bin/wine")
        ]

        var found: [RuntimeInfo] = []
        for (name, path) in candidates where FileManager.default.isExecutableFile(atPath: path) {
            found.append(RuntimeInfo(name: name, executable: path, version: version(of: path)))
        }

        if let custom = ProcessInfo.processInfo.environment["GAMEPORTER_WINE"],
           FileManager.default.isExecutableFile(atPath: custom) {
            found.append(RuntimeInfo(name: "Custom Wine", executable: custom, version: version(of: custom)))
        }
        return found
    }

    private static func version(of executable: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["--version"]
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
