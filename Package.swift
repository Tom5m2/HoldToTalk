// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HoldToTalk",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "HoldToTalk",
            path: "Sources/HoldToTalk"
        )
    ]
)
