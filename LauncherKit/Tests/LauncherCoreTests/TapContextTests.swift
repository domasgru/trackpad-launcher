import LauncherCore
import Testing

@Suite struct TapContextTests {
    @Test(arguments: [
        (Blocking.none, false), (.possible, false), (.dockSwipes, true), (.clicks, true),
    ])
    func theEstimateTakesFingersBesideAThumbAsAScrollMaybeUnderWay(level: Blocking, underWay: Bool) {
        #expect(TapContext.estimated(from: level, liftWindowIsOpen: false)
            == TapContext(blocking: level, liftWindowIsOpen: false, scrollMayBeUnderWay: underWay))
    }
}
