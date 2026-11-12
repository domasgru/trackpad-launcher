import LauncherCore
import Testing

@testable import LauncherPlatform

@Suite struct TrackpadClassificationTests {
    /// Each `product` is the IORegistry "Product" string as `ioreg -c AppleMultitouchDevice -r` prints it.
    @Test(arguments: [
        (product: "Apple Internal Keyboard / Trackpad", isBuiltIn: true, kind: TrackpadKind.builtIn),
        (product: "Magic Trackpad", isBuiltIn: false, kind: TrackpadKind.external),
        (product: "Magic Mouse", isBuiltIn: false, kind: nil),
        (product: "Apple Internal Keyboard / Trackpad", isBuiltIn: false, kind: TrackpadKind.external),
    ])
    func kindFromProductString(product: String, isBuiltIn: Bool, kind: TrackpadKind?) {
        #expect(trackpadKind(product: product, isBuiltIn: isBuiltIn) == kind)
    }

    private static func trackpad(_ id: UInt64, _ kind: TrackpadKind, _ width: Double = 160, _ height: Double = 115) -> Trackpad {
        Trackpad(id: TrackpadID(rawValue: id), kind: kind, surface: SurfaceSize(widthMM: width, heightMM: height))
    }

    @Test func eachListedDeviceRunsOnlyIfAskedForWithItsOwnEntrysCorner() {
        let listing = [
            (device: "built-in", trackpad: Self.trackpad(1, .builtIn, 124.8, 76.8)),
            (device: "magic", trackpad: Self.trackpad(2, .external)),
            (device: "magic 2", trackpad: Self.trackpad(3, .external)),
            (device: "unasked", trackpad: Self.trackpad(4, .external, 90, 60)),
        ]
        let entries = [
            TrackpadRun(Self.trackpad(3, .external), corner: .bottomRight),
            TrackpadRun(Self.trackpad(1, .builtIn, 124.8, 76.8), corner: .topLeft),
            TrackpadRun(Self.trackpad(2, .external, 100, 100), corner: .bottomLeft),
            TrackpadRun(Self.trackpad(9, .external), corner: .topRight),
        ]

        let started = devicesToRun(listing, entries)

        #expect(started.map(\.device) == ["built-in", "magic", "magic 2"])
        #expect(started.map(\.trackpad) == [listing[0].trackpad, listing[1].trackpad, listing[2].trackpad])
        #expect(started.map(\.corner) == [.topLeft, .bottomLeft, .bottomRight])
    }

    @Test func noEntriesRunNothing() {
        #expect(devicesToRun([(device: "built-in", trackpad: Self.trackpad(1, .builtIn))], []).isEmpty)
    }
}
