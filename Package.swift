// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AstraDial",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "AstraCore",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .testTarget(
            name: "AstraCoreTests",
            dependencies: ["AstraCore"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
