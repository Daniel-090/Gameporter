import Foundation

final class GameRegistry {
    private let file: URL

    init() throws {
        try GamePorterPaths.prepare()
        file = GamePorterPaths.games.appendingPathComponent("registry.json")
    }

    func all() throws -> [GameProfile] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let data = try Data(contentsOf: file)
        return try JSONDecoder().decode([GameProfile].self, from: data)
    }

    @discardableResult
    func add(_ game: GameProfile) throws -> GameProfile {
        var games = try all()
        games.removeAll { $0.id == game.id }
        games.append(game)
        let data = try JSONEncoder.pretty.encode(games)
        try data.write(to: file, options: .atomic)
        return game
    }

    @discardableResult
    func add(name: String, executable: String) throws -> GameProfile {
        try add(GameProfile(name: name, executablePath: executable))
    }

    func find(_ name: String) throws -> GameProfile? {
        let id = GameProfile.slug(name)
        return try all().first { $0.id == id }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
