// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GamePorter",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "gameporter", targets: ["GamePorter"])
    ],
    targets: [
        .executableTarget(name: "GamePorter"),
        .testTarget(name: "GamePorterTests", dependencies: ["GamePorter"])
    ]
)
