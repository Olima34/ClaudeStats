// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ClaudeStats",
    defaultLocalization: "fr",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "ClaudeStats",
            path: "Sources/ClaudeStats",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
