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
}
