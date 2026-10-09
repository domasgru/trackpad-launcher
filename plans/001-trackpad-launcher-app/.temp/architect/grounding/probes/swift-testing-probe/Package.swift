// swift-tools-version: 6.0
// Probe: does `swift test` run Swift Testing (@Test) with this Command Line Tools toolchain, and can
// an executable target (macOS app shell) plus a library target (core) coexist with a test target?
import PackageDescription
let package = Package(
    name: "ProbePkg",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "Core"),
        .executableTarget(name: "App", dependencies: ["Core"]),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
    ]
)
