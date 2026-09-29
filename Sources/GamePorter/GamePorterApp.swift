import Foundation

final class GamePorterApp {
    private let registry: GameRegistry

    init() {
        do {
            registry = try GameRegistry()
        } catch {
            fatalError("Could not initialize GamePorter: \(error)")
        }
    }

    func run(arguments: [String]) {
        guard let command = arguments.first else {
            help()
            return
        }

        do {
            switch command {
            case "list-runtimes":
                listRuntimes()
            case "list-games":
                listGames()
            case "add":
                guard arguments.count >= 3 else { print("Usage: gameporter add <name> <exe>"); return }
                let game = GameProfile(name: arguments[1], executablePath: arguments[2])
                try registry.add(game)
                print("Added \(game.name)")
            case "info":
                guard arguments.count >= 2 else { print("Usage: gameporter info <name>"); return }
                guard let game = try registry.find(arguments[1]) else { print("Game not found"); return }
                print("Name: \(game.name)")
                print("Executable: \(game.executablePath)")
                print("Runtime: \(game.runtime)")
            case "run":
                guard arguments.count >= 2 else { print("Usage: gameporter run <name>"); return }
                guard let game = try registry.find(arguments[1]) else { print("Game not found"); return }
                try GameRunner().run(game)
            default:
                help()
            }
        } catch {
            print("Error: \(error)")
        }
    }

    private func listRuntimes() {
        let runtimes = RuntimeDetector.detect()
        if runtimes.isEmpty { print("No supported runtimes detected."); return }
        for runtime in runtimes {
            print("\(runtime.name): \(runtime.executable)\(runtime.version.map { " — \($0)" } ?? "")")
        }
    }

    private func listGames() {
        do {
            let games = try registry.all()
            if games.isEmpty { print("No games registered."); return }
            for game in games { print("\(game.name) — \(game.executablePath)") }
        } catch {
            print("Error: \(error)")
        }
    }

    private func help() {
        print("""
        GamePorter

        Commands:
          list-runtimes
          list-games
          add <name> <exe>
          info <name>
          run <name>
        """)
    }
}
