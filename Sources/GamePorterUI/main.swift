import SwiftUI

struct RegisteredGame: Identifiable {
    let id: String
    let name: String
    let executablePath: String
}

@main
struct GamePorterUIApp: App {
    var body: some Scene {
        WindowGroup("GamePorter") {
            ContentView().frame(minWidth: 760, minHeight: 520)
        }
    }
}

struct ContentView: View {
    @State private var games: [RegisteredGame] = []
    @State private var selectedID: String?
    @State private var status = "Ready"

    var selectedGame: RegisteredGame? { games.first { $0.id == selectedID } }

    var body: some View {
        NavigationSplitView {
            List(games, selection: $selectedID) { game in
                VStack(alignment: .leading) {
                    Text(game.name).font(.headline)
                    Text(game.executablePath).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .navigationTitle("Games")
            .toolbar { Button("Refresh") { reload() } }
        } detail: {
            if let game = selectedGame {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Image(systemName: "gamecontroller.fill").font(.system(size: 42))
                        VStack(alignment: .leading) {
                            Text(game.name).font(.largeTitle.bold())
                            Text(game.executablePath).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Play") { launch(game) }.buttonStyle(.borderedProminent).keyboardShortcut(.return)
                    }
                    GroupBox("Status") {
                        Text(status).frame(maxWidth: .infinity, alignment: .leading).padding()
                    }
                    Spacer()
                }.padding(28)
            } else {
                VStack(spacing: 12) {\n                    Image(systemName: "gamecontroller").font(.system(size: 42))\n                    Text("No Game Selected").font(.title2.bold())\n                    Text("Add a game with the CLI, then refresh.") .foregroundStyle(.secondary)\n                }
            }
        }
        .task { reload() }
    }

    private func registryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/GamePorter/games/registry.json")
    }

    private func reload() {
        do {
            let data = try Data(contentsOf: registryURL())
            let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            games = raw.compactMap {
                guard let id = $0["id"] as? String, let name = $0["name"] as? String,
                      let executablePath = $0["executablePath"] as? String else { return nil }
                return RegisteredGame(id: id, name: name, executablePath: executablePath)
            }
            if selectedID == nil { selectedID = games.first?.id }
            status = "(games.count) game(s) registered"
        } catch {
            games = []
            status = "No registry yet. Add a game with the CLI."
        }
    }

    private func launch(_ game: RegisteredGame) {
        status = "Launching (game.name)…"
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["gameporter", "run", game.name]
            do {
                try process.run(); process.waitUntilExit()
                DispatchQueue.main.async { status = process.terminationStatus == 0 ? "Game exited." : "Game failed. Check the GamePorter log." }
            } catch {
                DispatchQueue.main.async { status = "Could not find gameporter in PATH." }
            }
        }
    }
}
