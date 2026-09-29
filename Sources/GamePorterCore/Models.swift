import Foundation

struct GameProfile: Codable, Identifiable {
    let id: String
    var name: String
    var executablePath: String
    var runtime: String
    var graphics: GraphicsConfiguration
    var environment: [String: String]

    init(name: String, executablePath: String, runtime: String = "auto", graphics: GraphicsConfiguration = GraphicsConfiguration(), environment: [String: String] = [:]) {
        self.id = Self.slug(name)
        self.name = name
        self.executablePath = executablePath
        self.runtime = runtime
        self.graphics = graphics
        self.environment = environment
    }

    static func slug(_ value: String) -> String {
        let lowered = value.lowercased()
        let allowed = lowered.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return String(allowed).split(separator: "-").filter { !$0.isEmpty }.joined(separator: "-")
    }
}