// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TypetodoCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "TypetodoCore",
            targets: ["TypetodoCore"]
        ),
    ],
    targets: [
        .target(
            name: "TypetodoCore",
            path: "Sources/TypetodoCore",
            linkerSettings: [
                .linkedFramework("IOKit", .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "TypetodoCoreTests",
            dependencies: ["TypetodoCore"],
            path: "Tests/TypetodoCoreTests"
        )
    ]
)
