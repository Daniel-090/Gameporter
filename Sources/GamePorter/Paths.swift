import Foundation

enum GamePorterPaths {
    static let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/GamePorter")
    static let games = root.appendingPathComponent("games")
    static let prefixes = root.appendingPathComponent("prefixes")
    static let logs = root.appendingPathComponent("logs")

    static func prepare() throws {
        let fm = FileManager.default
        for path in [root, games, prefixes, logs] {
            try fm.createDirectory(at: path, withIntermediateDirectories: true)
        }
    }
}
