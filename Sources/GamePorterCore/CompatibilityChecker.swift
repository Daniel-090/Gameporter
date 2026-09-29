import Foundation

enum PEArchitecture: String { case x86 = "x86", x86_64 = "x86_64", arm64 = "arm64", unknown = "unknown" }
enum CompatibilityLevel: String { case ready = "READY", warning = "WARNING", blocked = "BLOCKED" }

struct CompatibilityReport {
    let level: CompatibilityLevel
    let gameArchitecture: PEArchitecture?
    let runtime: RuntimeInfo?
    let messages: [String]
    var summary: String {
        var lines = ["Compatibility: \(level.rawValue)"]
        if let gameArchitecture { lines.append("Game architecture: \(gameArchitecture.rawValue)") }
        if let runtime {
            lines.append("Runtime: \(runtime.name) [\(runtime.architecture.rawValue)]")
            lines.append("D3DMetal: \(runtime.supportsD3DMetal ? "detected" : "not detected")")
        }
        lines.append(contentsOf: messages.map { "- \($0)" }); return lines.joined(separator: "\n")
    }
}

enum CompatibilityChecker {
    static func check(_ game: GameProfile) -> CompatibilityReport {
        let executable = URL(fileURLWithPath: game.executablePath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: executable.path) else { return CompatibilityReport(level: .blocked, gameArchitecture: nil, runtime: nil, messages: ["Executable does not exist: \(executable.path)"]) }
        guard let architecture = PEParser.architecture(of: executable) else { return CompatibilityReport(level: .blocked, gameArchitecture: nil, runtime: nil, messages: ["The selected file is not a readable Windows PE executable."]) }
        let runtime = game.runtime == "auto" ? RuntimeDetector.bestRuntime() : RuntimeDetector.detect().first { $0.name.caseInsensitiveCompare(game.runtime) == .orderedSame || $0.executable == game.runtime }
        guard let runtime else { return CompatibilityReport(level: .blocked, gameArchitecture: architecture, runtime: nil, messages: ["No compatible Windows runtime was detected."]) }
        var messages: [String] = []; var level: CompatibilityLevel = .ready
        if runtime.architecture == .unknown { level = .warning; messages.append("Runtime architecture could not be identified.") }
        if architecture == .x86_64 && runtime.architecture == .i386 { level = .blocked; messages.append("The game is 64-bit but the selected runtime is 32-bit.") }
        if game.graphics.backend == .d3dMetal && !runtime.supportsD3DMetal { level = .blocked; messages.append("D3DMetal was requested but no D3DMetal installation was detected.") }
        if runtime.kind == .gptk && !runtime.supportsD3DMetal { level = .warning; messages.append("GPTK runtime detected, but D3DMetal could not be located. Check GAMEPORTER_D3DMETAL.") }
        if architecture == .x86 { level = level == .blocked ? .blocked : .warning; messages.append("32-bit Windows executables may require a runtime build with 32-bit support.") }
        if architecture == .arm64 { level = level == .blocked ? .blocked : .warning; messages.append("Windows ARM64 support depends on the selected runtime and game dependencies.") }
        return CompatibilityReport(level: level, gameArchitecture: architecture, runtime: runtime, messages: messages)
    }
}

private enum PEParser {
    static func architecture(of url: URL) -> PEArchitecture? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), data.count >= 0x40, data[0] == 0x4D, data[1] == 0x5A else { return nil }
        let peOffset = Int(UInt32(data[0x3C]) | (UInt32(data[0x3D]) << 8) | (UInt32(data[0x3E]) << 16) | (UInt32(data[0x3F]) << 24))
        guard peOffset >= 0, peOffset + 6 <= data.count, data[peOffset] == 0x50, data[peOffset+1] == 0x45, data[peOffset+2] == 0, data[peOffset+3] == 0 else { return nil }
        let machine = UInt16(data[peOffset+4]) | (UInt16(data[peOffset+5]) << 8)
        switch machine { case 0x014c: return .x86; case 0x8664: return .x86_64; case 0xAA64: return .arm64; default: return .unknown }
    }
}