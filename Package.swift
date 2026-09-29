// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GamePorter",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "gameporter", targets: ["GamePorter"]),
        .executable(name: "GamePorterUI", targets: ["GamePorterUI"])
    ],
    targets: [
        .target(name: "GamePorterCore", path: "Sources/GamePorterCore"),
        .executableTarget(name: "GamePorter", dependencies: ["GamePorterCore"], path: "Sources/GamePorter"),
        .executableTarget(name: "GamePorterUI", dependencies: ["GamePorterCore"], path: "Sources/GamePorterUI"),
        .testTarget(name: "GamePorterTests", dependencies: ["GamePorterCore"])
    ]
)
