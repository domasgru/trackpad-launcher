import LauncherCore
import Testing

@Suite struct TapContextTests {
    @Test(arguments: [
        (Blocking.none, false), (.possible, false), (.dockSwipes, true), (.clicks, true), (.pressDrags, true),
    ])
    func theEstimateTakesFingersBesideAThumbAsAScrollMaybeUnderWay(level: Blocking, underWay: Bool) {
        #expect(TapContext.estimated(from: level) == TapContext(blocking: level, scrollMayBeUnderWay: underWay))
    }
}
