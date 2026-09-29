import Foundation

struct RuntimeInfo {
    let name: String
    let executable: String
    let version: String?
    let kind: RuntimeKind
}

enum RuntimeKind: String {
    case wine
    case gptk
    case unknown
}

enum RuntimeDetector {
    static func detect() -> [RuntimeInfo] {
        var found: [RuntimeInfo] = []

        let wineCandidates = [
            ("Wine (Homebrew)", "/opt/homebrew/bin/wine64"),
            ("Wine (Intel Homebrew)", "/usr/local/bin/wine64"),
            ("Wine", "/usr/bin/wine")
        ]

        for (name, path) in wineCandidates where FileManager.default.isExecutableFile(atPath: path) {
            found.append(RuntimeInfo(name: name, executable: path, version: version(of: path), kind: .wine))
        }

        if let custom = ProcessInfo.processInfo.environment["GAMEPORTER_WINE"],
           FileManager.default.isExecutableFile(atPath: custom) {
            found.append(RuntimeInfo(name: "Custom Wine", executable: custom, version: version(of: custom), kind: .wine))
        }

        // GPTK commonly exposes wine/wine64 inside a Game Porting Toolkit installation.
        let gptkCandidates = [
            "/opt/homebrew/opt/game-porting-toolkit/bin/wine64",
            "/opt/homebrew/opt/game-porting-toolkit/bin/wine",
            "/usr/local/opt/game-porting-toolkit/bin/wine64",
            "/usr/local/opt/game-porting-toolkit/bin/wine"
        ]

        for path in gptkCandidates where FileManager.default.isExecutableFile(atPath: path) {
            found.append(RuntimeInfo(
                name: "Apple Game Porting Toolkit",
                executable: path,
                version: version(of: path),
                kind: .gptk
            ))
        }

        return deduplicate(found)
    }

    static func bestRuntime() -> RuntimeInfo? {
        let runtimes = detect()
        return runtimes.first(where: { $0.kind == .gptk })
            ?? runtimes.first(where: { $0.kind == .wine })
    }

    private static func deduplicate(_ runtimes: [RuntimeInfo]) -> [RuntimeInfo] {
        var seen = Set<String>()
        return runtimes.filter { seen.insert($0.executable).inserted }
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
