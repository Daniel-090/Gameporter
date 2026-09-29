import Foundation

struct RuntimeInfo {
    let name: String
    let executable: String
    let version: String?
    let kind: RuntimeKind
    let supportsD3DMetal: Bool
}

enum RuntimeKind: String {
    case wine
    case gptk
    case unknown
}

extension RuntimeInfo {
    var path: String { executable }
}

enum RuntimeDetector {
    static func detect() -> [RuntimeInfo] {
        var found: [RuntimeInfo] = []
        let wineCandidates = [
            ("Wine (Homebrew)", "/opt/homebrew/bin/wine64", RuntimeKind.wine, false),
            ("Wine (Intel Homebrew)", "/usr/local/bin/wine64", RuntimeKind.wine, false),
            ("Wine", "/usr/bin/wine", RuntimeKind.wine, false)
        ]

        for (name, path, kind, d3dmetal) in wineCandidates where FileManager.default.isExecutableFile(atPath: path) {
            found.append(RuntimeInfo(name: name, executable: path, version: version(of: path), kind: kind, supportsD3DMetal: d3dmetal))
        }

        let gptkCandidates = [
            "/opt/homebrew/opt/game-porting-toolkit/bin/wine64",
            "/opt/homebrew/opt/game-porting-toolkit/bin/wine",
            "/usr/local/opt/game-porting-toolkit/bin/wine64",
            "/usr/local/opt/game-porting-toolkit/bin/wine"
        ]
        for path in gptkCandidates where FileManager.default.isExecutableFile(atPath: path) {
            found.append(RuntimeInfo(name: "Apple Game Porting Toolkit", executable: path, version: version(of: path), kind: .gptk, supportsD3DMetal: true))
        }

        if let custom = ProcessInfo.processInfo.environment["GAMEPORTER_WINE"],
           FileManager.default.isExecutableFile(atPath: custom) {
            found.append(RuntimeInfo(name: "Custom Wine", executable: custom, version: version(of: custom), kind: .wine, supportsD3DMetal: false))
        }

        return deduplicate(found)
    }

    static func bestRuntime() -> RuntimeInfo? {
        detect().sorted {
            let lhs = $0.kind == .gptk ? 0 : 1
            let rhs = $1.kind == .gptk ? 0 : 1
            return lhs < rhs
        }.first
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
        } catch { return nil }
    }
}
