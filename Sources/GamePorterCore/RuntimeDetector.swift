import Foundation

enum RuntimeArchitecture: String { case arm64, x86_64, i386, unknown }

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

enum RuntimeKind: String { case wine, gptk, unknown }
extension RuntimeInfo { var path: String { executable } }

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
        if let customWine { candidates.insert((customWine, .wine, false), at: 0) }
        for (path, kind, d3dmetalHint) in candidates {
            guard FileManager.default.isExecutableFile(atPath: path) else { continue }
            let d3dMetalPath = findD3DMetal(for: path, hinted: d3dmetalHint)
            found.append(RuntimeInfo(name: kind == .gptk ? "Apple Game Porting Toolkit" : "Wine", executable: path, launcher: kind == .gptk ? findGPTKLauncher(near: path) : nil, version: version(of: path), kind: kind, supportsD3DMetal: d3dMetalPath != nil, d3dMetalPath: d3dMetalPath, architecture: architecture(of: path)))
        }
        return deduplicate(found)
    }

    static func bestRuntime() -> RuntimeInfo? {
        detect().min {
            let lg = $0.kind == .gptk, rg = $1.kind == .gptk
            if lg != rg { return lg }
            if $0.supportsD3DMetal != $1.supportsD3DMetal { return $0.supportsD3DMetal }
            return $0.executable < $1.executable
        }
    }

    private static func deduplicate(_ runtimes: [RuntimeInfo]) -> [RuntimeInfo] {
        var seen = Set<String>(); return runtimes.filter { seen.insert($0.executable).inserted }
    }

    private static func version(of executable: String) -> String? {
        run(executable: executable, arguments: ["--version"])?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func architecture(of executable: String) -> RuntimeArchitecture {
        let output = run(executable: "/usr/bin/file", arguments: [executable]) ?? ""
        if output.contains("arm64") { return .arm64 }
        if output.contains("x86_64") { return .x86_64 }
        if output.contains("i386") { return .i386 }
        return .unknown
    }

    private static func run(executable: String, arguments: [String]) -> String? {
        let p = Process(), pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: executable); p.arguments = arguments; p.standardOutput = pipe; p.standardError = pipe
        do { try p.run(); p.waitUntilExit(); return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) } catch { return nil }
    }

    private static func findGPTKLauncher(near runtime: String) -> String? {
        let fm = FileManager.default
        let candidates = [ProcessInfo.processInfo.environment["GAMEPORTER_GPTK_LAUNCHER"], "/opt/homebrew/bin/gameportingtoolkit", "/usr/local/bin/gameportingtoolkit"].compactMap { $0 }
        for candidate in candidates where fm.isExecutableFile(atPath: candidate) { return candidate }
        var cursor = URL(fileURLWithPath: runtime).standardizedFileURL.deletingLastPathComponent()
        for _ in 0..<5 {
            let candidate = cursor.appendingPathComponent("gameportingtoolkit").path
            if fm.isExecutableFile(atPath: candidate) { return candidate }
            cursor.deleteLastPathComponent()
        }
        return nil
    }

    private static func findD3DMetal(for runtime: String, hinted: Bool) -> String? {
        let fm = FileManager.default; var roots: [URL] = []
        if let override = ProcessInfo.processInfo.environment["GAMEPORTER_D3DMETAL"] {
            let url = URL(fileURLWithPath: override).standardizedFileURL
            roots += [url, url.deletingLastPathComponent()]
        }
        var cursor = URL(fileURLWithPath: runtime).standardizedFileURL.deletingLastPathComponent()
        for _ in 0..<5 { roots.append(cursor); cursor = cursor.deletingLastPathComponent() }
        roots += [URL(fileURLWithPath: "/Library/Frameworks"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Frameworks"), URL(fileURLWithPath: "/opt/homebrew/opt/game-porting-toolkit/lib"), URL(fileURLWithPath: "/usr/local/opt/game-porting-toolkit/lib")]
        for root in roots {
            for name in ["D3DMetal.framework", "d3dmetal.dll", "D3DMetal.dll"] {
                let candidate = root.appendingPathComponent(name).path
                if fm.fileExists(atPath: candidate) { return candidate }
            }
        }
        return hinted ? nil : nil
    }
}