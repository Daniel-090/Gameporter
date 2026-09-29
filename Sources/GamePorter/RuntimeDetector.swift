import Foundation

enum RuntimeArchitecture: String {
    case arm64
    case x86_64
    case i386
    case unknown
}

struct RuntimeInfo {
    let name: String
    let executable: String
    let launcher: String?
    let version: String?
    let kind: RuntimeKind
    let supportsD3DMetal: Bool
    let d3dMetalPath: String?
    let architecture: RuntimeArchitecture
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

        let customGPTK = ProcessInfo.processInfo.environment["GAMEPORTER_GPTK"]
        let customWine = ProcessInfo.processInfo.environment["GAMEPORTER_WINE"]

        var candidates: [(String, RuntimeKind, Bool)] = [
            ("/opt/homebrew/opt/game-porting-toolkit/bin/wine64", .gptk, true),
            ("/opt/homebrew/opt/game-porting-toolkit/bin/wine", .gptk, true),
            ("/usr/local/opt/game-porting-toolkit/bin/wine64", .gptk, true),
            ("/usr/local/opt/game-porting-toolkit/bin/wine", .gptk, true),
            ("/opt/homebrew/bin/wine64", .wine, false),
            ("/usr/local/bin/wine64", .wine, false),
            ("/usr/bin/wine", .wine, false)
        ]

        if let customGPTK {
            let root = URL(fileURLWithPath: customGPTK).standardizedFileURL
            candidates.insert((root.appendingPathComponent("bin/wine64").path, .gptk, true), at: 0)
            candidates.insert((root.appendingPathComponent("bin/wine").path, .gptk, true), at: 1)
        }

        if let customWine {
            candidates.insert((customWine, .wine, false), at: 0)
        }

        for (path, kind, d3dmetalHint) in candidates {
            guard FileManager.default.isExecutableFile(atPath: path) else { continue }
            let d3dMetalPath = findD3DMetal(for: path, hinted: d3dmetalHint)
            let isGPTK = kind == .gptk
            found.append(RuntimeInfo(
                name: isGPTK ? "Apple Game Porting Toolkit" : "Wine",
                executable: path,
                launcher: isGPTK ? findGPTKLauncher(near: path) : nil,
                version: version(of: path),
                kind: kind,
                supportsD3DMetal: d3dMetalPath != nil,
                d3dMetalPath: d3dMetalPath,
                architecture: architecture(of: path)
            ))
        }

        return deduplicate(found)
    }

    static func bestRuntime() -> RuntimeInfo? {
        detect().min { lhs, rhs in
            let lhsGPTK = lhs.kind == .gptk
            let rhsGPTK = rhs.kind == .gptk
            if lhsGPTK != rhsGPTK { return lhsGPTK }
            if lhs.supportsD3DMetal != rhs.supportsD3DMetal { return lhs.supportsD3DMetal }
            return lhs.executable < rhs.executable
        }
    }

    private static func deduplicate(_ runtimes: [RuntimeInfo]) -> [RuntimeInfo] {
        var seen = Set<String>()
        return runtimes.filter { seen.insert($0.executable).inserted }
    }

    private static func version(of executable: String) -> String? {
        run(executable: executable, arguments: ["--version"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func architecture(of executable: String) -> RuntimeArchitecture {
        let output = run(executable: "/usr/bin/file", arguments: [executable]) ?? ""
        if output.contains("arm64") { return .arm64 }
        if output.contains("x86_64") { return .x86_64 }
        if output.contains("i386") { return .i386 }
        return .unknown
    }

    private static func run(executable: String, arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        } catch {
            return nil
        }
    }

    private static func findGPTKLauncher(near runtime: String) -> String? {
        let fm = FileManager.default
        let candidates = [
            ProcessInfo.processInfo.environment["GAMEPORTER_GPTK_LAUNCHER"],
            "/opt/homebrew/bin/gameportingtoolkit",
            "/usr/local/bin/gameportingtoolkit"
        ].compactMap { $0 }

        for candidate in candidates where fm.isExecutableFile(atPath: candidate) {
            return candidate
        }

        let runtimeURL = URL(fileURLWithPath: runtime).standardizedFileURL
        var cursor = runtimeURL.deletingLastPathComponent()
        for _ in 0..<5 {
            let candidate = cursor.appendingPathComponent("gameportingtoolkit").path
            if fm.isExecutableFile(atPath: candidate) {
                return candidate
            }
            cursor.deleteLastPathComponent()
        }

        return nil
    }

    private static func findD3DMetal(for runtime: String, hinted: Bool) -> String? {
        let fm = FileManager.default
        var roots: [URL] = []

        if let override = ProcessInfo.processInfo.environment["GAMEPORTER_D3DMETAL"] {
            let url = URL(fileURLWithPath: override).standardizedFileURL
            roots.append(url)
            roots.append(url.deletingLastPathComponent())
        }

        let executableURL = URL(fileURLWithPath: runtime).standardizedFileURL
        var cursor = executableURL.deletingLastPathComponent()
        for _ in 0..<5 {
            roots.append(cursor)
            cursor = cursor.deletingLastPathComponent()
        }

        roots += [
            URL(fileURLWithPath: "/Library/Frameworks"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Frameworks"),
            URL(fileURLWithPath: "/opt/homebrew/opt/game-porting-toolkit/lib"),
            URL(fileURLWithPath: "/usr/local/opt/game-porting-toolkit/lib")
        ]

        let names = ["D3DMetal.framework", "d3dmetal.dll", "D3DMetal.dll"]
        for root in roots {
            for name in names {
                let candidate = root.appendingPathComponent(name).path
                if fm.fileExists(atPath: candidate) {
                    return candidate
                }
            }
        }

        return hinted ? nil : nil
    }
}
