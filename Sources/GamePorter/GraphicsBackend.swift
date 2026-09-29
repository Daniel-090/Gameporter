import Foundation

enum GraphicsAPI: String, Codable {
    case auto
    case directX11
    case directX12
}

enum GraphicsBackend: String, Codable {
    case auto
    case dxvk
    case d3dMetal
}

struct GraphicsConfiguration: Codable {
    var api: GraphicsAPI = .auto
    var backend: GraphicsBackend = .auto
    var esync: Bool = true
    var fsync: Bool = true
    var hud: Bool = false
}

enum GraphicsConfigurator {
    static func resolve(_ requested: GraphicsConfiguration, runtime: RuntimeInfo) -> GraphicsConfiguration {
        var result = requested
        if result.backend == .auto {
            result.backend = runtime.supportsD3DMetal ? .d3dMetal : .dxvk
        }
        if result.api == .auto {
            result.api = result.backend == .d3dMetal ? .directX12 : .directX11
        }
        return result
    }

    static func environment(for config: GraphicsConfiguration) -> [String: String] {
        var env: [String: String] = [:]
        switch config.backend {
        case .dxvk:
            env["WINEDLLOVERRIDES"] = "d3d11=n,b"
        case .d3dMetal:
            env["WINEDLLOVERRIDES"] = "d3d11=n,b;dxgi=n,b"
        case .auto:
            break
        }
        if config.esync { env["WINEESYNC"] = "1" }
        if config.fsync { env["WINEFSYNC"] = "1" }
        if config.hud { env["DXVK_HUD"] = "1" }
        return env
    }
}
