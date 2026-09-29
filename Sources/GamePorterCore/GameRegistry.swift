import Foundation

final class GameRegistry {
    private let file: URL

    init() throws {
        try GamePorterPaths.prepare()
        file = GamePorterPaths.games.appendingPathComponent("registry.json")
    }

    func all() throws -> [GameProfile] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode([GameProfile].self, from: Data(contentsOf: file))
    }

    @discardableResult
    func add(_ game: GameProfile) throws -> GameProfile {
        var games = try all()
        games.removeAll { $0.id == game.id }
        games.append(game)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(games).write(to: file, options: .atomic)
        return game
    }

    @discardableResult
    func add(name: String, executable: String) throws -> GameProfile { try add(GameProfile(name: name, executablePath: executable)) }
    func find(_ name: String) throws -> GameProfile? { try all().first { $0.id == GameProfile.slug(name) } }
}