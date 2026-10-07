// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ShareMyInternetBeta",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ShareMyInternetBeta", path: "Sources/ShareMyInternetBeta")
    ]
)
