import XCTest
@testable import GamePorter

final class GamePorterTests: XCTestCase {
    func testSlug() {
        XCTAssertEqual(GameProfile.slug("Fortnite Test"), "fortnite-test")
        XCTAssertEqual(GameProfile.slug("My_Game!"), "my-game")
    }

    func testGraphicsResolution() {
        let runtime = RuntimeInfo(
            name: "Test GPTK",
            executable: "/tmp/wine64",
            version: "test",
            kind: .gptk,
            supportsD3DMetal: true,
            d3dMetalPath: "/tmp/D3DMetal.framework",
            architecture: .arm64
        )

        let resolved = GraphicsConfigurator.resolve(GraphicsConfiguration(), runtime: runtime)

        XCTAssertEqual(resolved.backend, .d3dMetal)
        XCTAssertEqual(resolved.api, .directX12)
    }

    func testGraphicsEnvironment() {
        let environment = GraphicsConfigurator.environment(
            for: GraphicsConfiguration(api: .directX11, backend: .dxvk, esync: true, fsync: false, hud: true)
        )

        XCTAssertEqual(environment["WINEDLLOVERRIDES"], "d3d11=n,b")
        XCTAssertEqual(environment["WINEESYNC"], "1")
        XCTAssertNil(environment["WINEFSYNC"])
        XCTAssertEqual(environment["DXVK_HUD"], "1")
    }
}
