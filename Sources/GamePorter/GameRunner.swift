import Foundation

enum GameRunnerError: LocalizedError {
    case runtimeMissing
    case executableMissing(String)

    var errorDescription: String? {
        switch self {
        case .runtimeMissing: return "No compatible Windows runtime was detected."
        case .executableMissing(let path): return "Game executable does not exist: \(path)"
        }
    }
}

final class GameRunner {
    func run(_ game: GameProfile) throws {
        let executable = URL(fileURLWithPath: game.executablePath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: executable.path) else {
            throw GameRunnerError.executableMissing(executable.path)
        }

        let runtimes = RuntimeDetector.detect()
        let runtime: RuntimeInfo?
        if game.runtime == "auto" {
            runtime = RuntimeDetector.bestRuntime()
        } else {
            runtime = runtimes.first { $0.name.caseInsensitiveCompare(game.runtime) == .orderedSame }
                ?? runtimes.first { $0.executable == game.runtime }
        }

        guard let runtime else { throw GameRunnerError.runtimeMissing }

        let prefix = GamePorterPaths.prefix(for: game)
        try FileManager.default.createDirectory(at: prefix, withIntermediateDirectories: true)
        try GamePorterPaths.ensureDirectories()

        var environment = ProcessInfo.processInfo.environment
        environment.merge(GraphicsEnvironment.environment(for: game.graphics), uniquingKeysWith: { _, new in new })
        environment.merge(game.environment, uniquingKeysWith: { _, new in new })
        environment["WINEPREFIX"] = prefix.path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: runtime.executable)
        process.arguments = [executable.path]
        process.environment = environment
        process.currentDirectoryURL = executable.deletingLastPathComponent()

        let logURL = GamePorterPaths.log(for: game)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let log = try FileHandle(forWritingTo: logURL)
        process.standardOutput = log
        process.standardError = log

        print("Launching \(game.name)")
        print("Runtime: \(runtime.name)")
        print("Graphics: \(game.graphics.backend.rawValue) / \(game.graphics.api.rawValue)")

        try process.run()
        process.waitUntilExit()
        try log.close()
        print("Game exited with code \(process.terminationStatus)")
    }
}
