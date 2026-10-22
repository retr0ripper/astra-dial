// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AstraDial",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "astra-probe", targets: ["astra-probe"]),
    ],
    targets: [
        .target(
            name: "AstraCore",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "astra-probe",
            dependencies: ["AstraCore"],
            path: "Tools/astra-probe"
        ),
        .testTarget(
            name: "AstraCoreTests",
            dependencies: ["AstraCore"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
