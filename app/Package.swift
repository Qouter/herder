// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Herder",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Herder",
            targets: ["Herder"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Herder",
            path: "Sources/Herder"
        )
    ]
)
