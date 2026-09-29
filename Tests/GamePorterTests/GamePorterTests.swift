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
            launcher: nil,
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

    func testCompatibilityDetects64BitPE() throws {
        var data = Data(repeating: 0, count: 512)
        data[0] = 0x4D
        data[1] = 0x5A
        data[0x3C] = 0x80
        data[0x80] = 0x50
        data[0x81] = 0x45
        data[0x82] = 0x00
        data[0x83] = 0x00
        data[0x84] = 0x64
        data[0x85] = 0x86

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gameporter-test.exe")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let profile = GameProfile(name: "Test", executablePath: url.path)
        let report = CompatibilityChecker.check(profile)

        XCTAssertEqual(report.gameArchitecture, .x86_64)
    }
}
