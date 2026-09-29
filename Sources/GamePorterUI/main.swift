import SwiftUI

@main
struct GamePorterUIApp: App {
    var body: some Scene {
        WindowGroup("GamePorter") {
            ContentView()
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var games: [GameProfile] = []
    @State private var selectedGameID: String?
    @State private var status = "Ready"

    private let registry = try? GameRegistry()
    private let runner = GameRunner()

    var selectedGame: GameProfile? {
        games.first { $0.id == selectedGameID }
    }

    var body: some View {
        NavigationSplitView {
            List(games, selection: $selectedGameID) { game in
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.name).font(.headline)
                    Text(game.executablePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Games")
            .toolbar {
                Button(action: reload) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        } detail: {
            if let game = selectedGame {
                GameDetailView(game: game, status: $status, onRun: run)
            } else {
                ContentUnavailableView(
                    "No Game Selected",
                    systemImage: "gamecontroller",
                    description: Text("Add a Windows executable from the CLI for now.")
                )
            }
        }
        .task { reload() }
    }

    private func reload() {
        guard let registry else {
            status = "Could not open GamePorter registry."
            return
        }
        do {
            games = try registry.all()
            if selectedGameID == nil { selectedGameID = games.first?.id }
            status = "\(games.count) game(s) registered"
        } catch {
            status = error.localizedDescription
        }
    }

    private func run(_ game: GameProfile) {
        status = "Launching \(game.name)…"
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try runner.run(game)
                DispatchQueue.main.async { status = "Game process exited." }
            } catch {
                DispatchQueue.main.async { status = error.localizedDescription }
            }
        }
    }
}

struct GameDetailView: View {
    let game: GameProfile
    @Binding var status: String
    let onRun: (GameProfile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 42))
                VStack(alignment: .leading) {
                    Text(game.name).font(.largeTitle.bold())
                    Text(game.executablePath).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Play") { onRun(game) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
            }

            GroupBox("Configuration") {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("Runtime", value: game.runtime)
                    LabeledContent("Graphics", value: "\(game.graphics.backend.rawValue) / \(game.graphics.api.rawValue)")
                    LabeledContent("Prefix", value: GamePorterPaths.prefix(for: game).path)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }

            GroupBox("Status") {
                Text(status)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }

            Spacer()
        }
        .padding(28)
    }
}
