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
            case "import":
                guard args.count >= 3 else { print("Usage: gameporter import <name> <exe> [--prefix <prefix>]"); return }
                let executable = URL(fileURLWithPath: args[2]).standardizedFileURL
                guard FileManager.default.isReadableFile(atPath: executable.path) else {
                    print("Executable not found or not readable: \(executable.path)")
                    return
                }
                var prefixPath: String?
                if let prefixIndex = args.firstIndex(of: "--prefix") {
                    guard prefixIndex + 1 < args.count else {
                        print("Usage: gameporter import <name> <exe> [--prefix <prefix>]")
                        return
                    }
                    prefixPath = URL(fileURLWithPath: args[prefixIndex + 1]).standardizedFileURL.path
                }
                let game = try registry.add(GameProfile(
                    name: args[1],
                    executablePath: executable.path,
                    prefixPath: prefixPath
                ))
                print("Imported \(game.name) [\(game.id)]")
                print("Executable: \(executable.path)")
                if let prefixPath { print("Prefix: \(prefixPath)") }
                print("Run with: gameporter run \"\(game.name)\"")
            case "scan":
                guard args.count >= 2 else { print("Usage: gameporter scan <folder>"); return }
                let folder = URL(fileURLWithPath: args[1]).standardizedFileURL
                let candidates = scanExecutables(in: folder)
                if candidates.isEmpty {
                    print("No Windows executables found.")
                } else {
                    print("Windows executables found:")
                    candidates.forEach { print("  \($0.path)") }
                }
            case "install":
                guard args.count >= 3 else { print("Usage: gameporter install <name> <installer.exe>"); return }

                let installerGame = GameProfile(name: args[1], executablePath: args[2])
                let registeredInstaller = try registry.add(installerGame)
                let prefix = GamePorterPaths.prefix(for: registeredInstaller)
                let before = Set(installedExecutables(in: prefix).map(\.path))

                print("Installing \(registeredInstaller.name)")
                print("Prefix: \(prefix.path)")
                try runner.run(registeredInstaller)

                let after = installedExecutables(in: prefix)
                let candidates = after.filter { !before.contains($0.path) }

                if candidates.count == 1, let executable = candidates.first {
                    let installedGame = GameProfile(
                        name: registeredInstaller.name,
                        executablePath: executable.path,
                        prefixPath: prefix.path,
                        runtime: registeredInstaller.runtime,
                        graphics: registeredInstaller.graphics,
                        environment: registeredInstaller.environment
                    )
                    try registry.add(installedGame)
                    print("Installer finished.")
                    print("Detected app: \(executable.path)")
                    print("Registered as: \(installedGame.name)")
                } else if candidates.isEmpty {
                    print("Installer finished, but no new application executable was detected.")
                    print("Use: gameporter add <name> <path/to/app.exe>")
                } else {
                    print("Installer finished. New application executables detected:")
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
                print("Prefix: \(game.prefixPath ?? GamePorterPaths.prefix(for: game).path)")
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
        scanExecutables(in: prefix.appendingPathComponent("drive_c"))
    }

    private func scanExecutables(in root: URL) -> [URL] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.path),
              let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else { return [] }

        return enumerator.compactMap { item -> URL? in
            guard let url = item as? URL,
                  url.pathExtension.lowercased() == "exe",
                  fm.isReadableFile(atPath: url.path) else { return nil }
            return url
        }
        .filter { !isSystemExecutable($0) }
        .sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }

    private func isSystemExecutable(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        let systemMarkers = [
            "/windows/",
            "/programdata/",
            "/internet explorer/",
            "/windows media player/",
            "/windows nt/",
            "/microsoft/",
            "/common files/"
        ]
        return systemMarkers.contains { path.contains($0) }
            || path.contains("/unins")
    }

    private func printUsage() {
        print("""
        GamePorter
          list-runtimes
          list-games
          add <name> <exe>
          import <name> <exe> [--prefix <prefix>]
          scan <folder>
          install <name> <installer.exe>
          info <name>
          check <name>
          run <name>
        """)
    }
}
