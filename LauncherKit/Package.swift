// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LauncherKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "LauncherCore", targets: ["LauncherCore"]),
        .library(name: "LauncherPlatform", targets: ["LauncherPlatform"]),
        .library(name: "LauncherUI", targets: ["LauncherUI"]),
    ],
    targets: [
        .binaryTarget(name: "Sparkle", path: "Vendor/Sparkle/Sparkle.xcframework"),
        .target(name: "LauncherCore"),
        .target(
            name: "LauncherPlatform",
            dependencies: ["LauncherCore", "Sparkle"]
        ),
        .target(
            name: "LauncherUI",
            dependencies: ["LauncherCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .target(name: "CardContract"),
        .executableTarget(name: "card-contract", dependencies: ["CardContract"]),
        .testTarget(name: "CardContractTests", dependencies: ["CardContract", "card-contract"]),
        .testTarget(name: "ReleaseTests"),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
        .testTarget(
            name: "LauncherUITests",
            dependencies: ["LauncherUI", "LauncherCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "LauncherPlatformTests", dependencies: ["LauncherPlatform", "LauncherCore"]),
    ],
    swiftLanguageModes: [.v6]
)
