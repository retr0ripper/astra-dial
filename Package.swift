// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AstraDial",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AstraDial", targets: ["AstraDial"]),
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
        .executableTarget(
            name: "AstraDial",
            dependencies: ["AstraCore"],
            linkerSettings: [.linkedFramework("ServiceManagement")]
        ),
        .testTarget(
            name: "AstraCoreTests",
            dependencies: ["AstraCore"]
        ),
        .testTarget(
            name: "AstraDialTests",
            dependencies: ["AstraDial"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
