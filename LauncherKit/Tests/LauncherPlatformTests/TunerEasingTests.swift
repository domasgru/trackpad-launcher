#if DEBUG
import LauncherCore
import Testing
@testable import LauncherPlatform

struct TunerEasingTests {
    @Test func `every named curve reads as its name and anything else as custom`() {
        #expect(NamedCurve.matching(CubicCurve(0.64, 0.7, 0.13, 0.92)) == .custom)
        for named in NamedCurve.allCases {
            if let curve = named.curve { #expect(NamedCurve.matching(curve) == named) }
        }
    }
}
#endif
