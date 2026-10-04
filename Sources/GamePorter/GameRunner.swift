import Foundation

enum GameRunnerError: LocalizedError {
    case runtimeMissing
    case executableMissing(String)
    case compatibilityBlocked(String)

    var errorDescription: String? {
        switch self {
        case .runtimeMissing: return "No compatible Windows runtime was detected."
        case .executableMissing(let path): return "Game executable does not exist: \(path)"
        case .compatibilityBlocked(let reason): return reason
        }
    }
}

final class GameRunner {
    func run(_ game: GameProfile) throws {
        let executable = URL(fileURLWithPath: game.executablePath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: executable.path) else {
            throw GameRunnerError.executableMissing(executable.path)
        }

        let report = CompatibilityChecker.check(game)
        if report.level == .blocked {
            throw GameRunnerError.compatibilityBlocked(report.summary)
        }

        if report.level == .warning {
            print("Compatibility warning:")
            report.messages.forEach { print("  - \($0)") }
        }

        let runtime: RuntimeInfo?
        if game.runtime == "auto" {
            runtime = RuntimeDetector.bestRuntime()
        } else {
            runtime = RuntimeDetector.detect().first {
                $0.name.caseInsensitiveCompare(game.runtime) == .orderedSame ||
                $0.executable == game.runtime
            }
        }
        guard let runtime else { throw GameRunnerError.runtimeMissing }

        let graphics = GraphicsConfigurator.resolve(game.graphics, runtime: runtime)
        let prefix: URL
        if let prefixPath = game.prefixPath, !prefixPath.isEmpty {
            prefix = URL(fileURLWithPath: prefixPath).standardizedFileURL
        } else {
            prefix = GamePorterPaths.prefix(for: game)
        }
        try FileManager.default.createDirectory(at: prefix, withIntermediateDirectories: true)
        try GamePorterPaths.ensureDirectories()

        var environment = ProcessInfo.processInfo.environment
        environment.merge(GraphicsConfigurator.environment(for: graphics), uniquingKeysWith: { _, new in new })
        environment.merge(game.environment, uniquingKeysWith: { _, new in new })
        environment["WINEPREFIX"] = prefix.path

        if let d3dMetalPath = runtime.d3dMetalPath {
            environment["GAMEPORTER_D3DMETAL_PATH"] = d3dMetalPath
        }

        let process = Process()
        let usesGPTKLauncher = runtime.kind == .gptk && runtime.launcher != nil
        process.executableURL = URL(fileURLWithPath: runtime.launcher ?? runtime.executable)

        if usesGPTKLauncher, let launcher = runtime.launcher {
            process.arguments = [prefix.path, executable.path]
            print("Launcher: \(launcher)")
        } else {
            process.arguments = [executable.path]
        }

        process.environment = environment
        process.currentDirectoryURL = executable.deletingLastPathComponent()

        let logURL = GamePorterPaths.log(for: game)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let log = try FileHandle(forWritingTo: logURL)
        process.standardOutput = log
        process.standardError = log

        print("Launching \(game.name)")
        print("Runtime: \(runtime.name) [\(runtime.architecture.rawValue)]")
        print("Graphics: \(graphics.backend.rawValue) / \(graphics.api.rawValue)")
        print("Prefix: \(prefix.path)")
        print("Log: \(logURL.path)")

        try process.run()
        process.waitUntilExit()
        try log.close()
        print("Game exited with code \(process.terminationStatus)")
    }
}
