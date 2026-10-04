import Foundation

struct GamePorterApp {
    private let registry = try! GameRegistry()
    private let runner = GameRunner()

    func run() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else { printUsage(); return }

        do {
            switch command {
            case "list-runtimes":
                let runtimes = RuntimeDetector.detect()
                if runtimes.isEmpty {
                    print("No Windows runtimes detected.")
                } else {
                    runtimes.forEach {
                        print("\($0.name): \($0.executable) [\($0.kind.rawValue)] arch=\($0.architecture.rawValue) d3dmetal=\($0.supportsD3DMetal) \($0.version ?? "")")
                    }
                }
            case "list-games":
                let games = try registry.all()
                if games.isEmpty { print("No games registered.") }
                else { games.forEach { print("\($0.name) [\($0.id)] runtime=\($0.runtime) graphics=\($0.graphics.backend.rawValue)") } }
            case "add":
                guard args.count >= 3 else { print("Usage: gameporter add <name> <exe>"); return }
                let game = try registry.add(name: args[1], executable: args[2])
                print("Added \(game.name) [\(game.id)]")
            case "install":
                guard args.count >= 3 else { print("Usage: gameporter install <name> <installer.exe>"); return }

                let installerGame = GameProfile(name: args[1], executablePath: args[2])
                let registeredInstaller = try registry.add(installerGame)
                print("Installing \(registeredInstaller.name)")
                print("Prefix: \(GamePorterPaths.prefix(for: registeredInstaller).path)")
                try runner.run(registeredInstaller)

                let prefix = GamePorterPaths.prefix(for: registeredInstaller)
                let candidates = installedExecutables(in: prefix)

                if candidates.count == 1, let executable = candidates.first {
                    let installedGame = GameProfile(
                        name: registeredInstaller.name,
                        executablePath: executable.path,
                        runtime: registeredInstaller.runtime,
                        graphics: registeredInstaller.graphics,
                        environment: registeredInstaller.environment
                    )
                    try registry.add(installedGame)
                    print("Installer finished.")
                    print("Detected app: \(executable.path)")
                    print("Registered as: \(installedGame.name)")
                } else if candidates.isEmpty {
                    print("Installer finished, but no application executable was detected.")
                    print("Use: gameporter add <name> <path/to/app.exe>")
                } else {
                    print("Installer finished. Multiple application executables detected:")
                    candidates.forEach { print("  \($0.path)") }
                    print("Register the one you want with: gameporter add <name> <path/to/app.exe>")
                }
            case "info":
                guard args.count >= 2 else { print("Usage: gameporter info <name>"); return }
                guard let game = try registry.find(args[1]) else { print("Game not found: \(args[1])"); return }
                print("Name: \(game.name)")
                print("Executable: \(game.executablePath)")
                print("Runtime: \(game.runtime)")
                print("Graphics: \(game.graphics.backend.rawValue) / \(game.graphics.api.rawValue)")
                print("Prefix: \(GamePorterPaths.prefix(for: game).path)")
            case "check":
                guard args.count >= 2 else { print("Usage: gameporter check <name>"); return }
                guard let game = try registry.find(args[1]) else { print("Game not found: \(args[1])"); return }
                let report = CompatibilityChecker.check(game)
                print(report.summary)
            case "run":
                guard args.count >= 2 else { print("Usage: gameporter run <name>"); return }
                guard let game = try registry.find(args[1]) else { print("Game not found: \(args[1])"); return }
                try runner.run(game)
            case "help", "--help", "-h": printUsage()
            default: print("Unknown command: \(command)"); printUsage()
            }
        } catch {
            fputs("GamePorter error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private func installedExecutables(in prefix: URL) -> [URL] {
        let fm = FileManager.default
        let root = prefix.appendingPathComponent("drive_c")
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return enumerator.compactMap { item -> URL? in
            guard let url = item as? URL,
                  url.pathExtension.lowercased() == "exe" else { return nil }

            let lower = url.path.lowercased()
            if lower.contains("/unins") || lower.contains("/windows/") || lower.contains("/programdata/") {
                return nil
            }

            let isProgramFile = lower.contains("/program files/")
                || lower.contains("/program files (x86)/")
            guard isProgramFile else { return nil }

            guard fm.isReadableFile(atPath: url.path) else { return nil }
            return url
        }
        .sorted { lhs, rhs in
            let lhsPath = lhs.path.lowercased()
            let rhsPath = rhs.path.lowercased()

            func score(_ path: String) -> Int {
                if path.contains("/internet explorer/") || path.contains("/windows media player/") || path.contains("/windows nt/") {
                    return 100
                }
                if path.contains("/microsoft/") {
                    return 90
                }
                return 0
            }

            let lhsScore = score(lhsPath)
            let rhsScore = score(rhsPath)
            if lhsScore != rhsScore { return lhsScore < rhsScore }

            return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
        }
    }

    private func printUsage() {
        print("""
        GamePorter
          list-runtimes
          list-games
          add <name> <exe>
          install <name> <installer.exe>
          info <name>
          check <name>
          run <name>
        """)
    }
}
