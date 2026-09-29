import Foundation

enum GamePorterPaths {
    static let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/GamePorter")
    static let games = root.appendingPathComponent("games")
    static let prefixes = root.appendingPathComponent("prefixes")
    static let logs = root.appendingPathComponent("logs")

    static func prepare() throws {
        let fm = FileManager.default
        for path in [root, games, prefixes, logs] {
            try fm.createDirectory(at: path, withIntermediateDirectories: true)
        }
    }

    static func ensureDirectories() throws { try prepare() }
    static func prefix(for game: GameProfile) -> URL { prefixes.appendingPathComponent(game.id, isDirectory: true) }
    static func log(for game: GameProfile) -> URL { logs.appendingPathComponent("\(game.id).log") }
}