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
        .target(name: "LauncherCore"),
        .target(name: "LauncherPlatform", dependencies: ["LauncherCore"]),
        .target(
            name: "LauncherUI",
            dependencies: ["LauncherCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // Test-only: the app the platform tests launch. Not a product, and outside the scanned source roots.
        .executableTarget(name: "LaunchProbe", path: "Tests/LaunchProbe"),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
        .testTarget(name: "LauncherPlatformTests", dependencies: ["LauncherPlatform", "LauncherCore", "LaunchProbe"]),
    ],
    swiftLanguageModes: [.v6]
)
