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

    func add(_ game: GameProfile) throws {
        var games = try all()
        games.removeAll { $0.id == game.id }
        games.append(game)
        let data = try JSONEncoder.pretty.encode(games)
        try data.write(to: file, options: .atomic)
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
