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
                let game = try registry.add(name: args[1], executable: args[2])
                print("Installing \(game.name)")
                print("Prefix: \(GamePorterPaths.prefix(for: game).path)")
                try runner.run(game)
                print("Installer finished. The app is registered as \(game.name).")
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
