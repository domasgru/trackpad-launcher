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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
    ],
    targets: [
        .target(name: "LauncherCore"),
        .target(
            name: "LauncherPlatform",
            dependencies: ["LauncherCore", .product(name: "Sparkle", package: "Sparkle")]
        ),
        .target(
            name: "LauncherUI",
            dependencies: ["LauncherCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
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
