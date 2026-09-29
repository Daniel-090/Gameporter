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
        .executableTarget(name: "GamePorter"),
        .executableTarget(name: "GamePorterUI"),
        .testTarget(name: "GamePorterTests", dependencies: ["GamePorter"])
    ]
)
