import XCTest
@testable import GamePorter

final class GamePorterTests: XCTestCase {
    func testSlug() {
        XCTAssertEqual(GameProfile.slug("Fortnite Test"), "fortnite-test")
        XCTAssertEqual(GameProfile.slug("My_Game!"), "my-game")
    }
}
