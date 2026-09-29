import Foundation

enum GameRunnerError: Error, CustomStringConvertible {
    case executableMissing
    case runtimeMissing
    var description: String {
        switch self {
        case .executableMissing: return "Game executable was not found."
        case .runtimeMissing: return "No compatible runtime was detected."
        }
    }
}

final class GameRunner {
    func run(_ game: GameProfile) throws {
        guard FileManager.default.isReadableFile(atPath: game.executablePath) else {
            throw GameRunnerError.executableMissing
        }

        guard let runtime = selectRuntime(for: game) else {
            throw GameRunnerError.runtimeMissing
        }

        let prefix = GamePorterPaths.prefixes.appendingPathComponent(game.id)
        let log = GamePorterPaths.logs.appendingPathComponent("\(game.id).log")
        try FileManager.default.createDirectory(at: prefix, withIntermediateDirectories: true)

        let process = Process()
        let output = try FileHandle(forWritingTo: log, createIfNeeded: true)
        process.executableURL = URL(fileURLWithPath: runtime.executable)
        process.arguments = [game.executablePath]
        process.environment = ProcessInfo.processInfo.environment.merging(
            game.environment.merging(["WINEPREFIX": prefix.path]) { _, new in new }
        ) { _, new in new }
        process.standardOutput = output
        process.standardError = output

        print("Launching \(game.name) with \(runtime.name)")
        print("Prefix: \(prefix.path)")
        print("Log: \(log.path)")
        try process.run()
    }

    private func selectRuntime(for game: GameProfile) -> RuntimeInfo? {
        let runtimes = RuntimeDetector.detect()
        if game.runtime != "auto" {
            return runtimes.first { $0.name.lowercased().contains(game.runtime.lowercased()) }
        }
        return runtimes.first
    }
}
