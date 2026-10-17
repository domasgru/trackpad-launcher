import CoreGraphics
import LauncherCore
import Testing

@testable import LauncherPlatform

@Suite struct TapEventTests {
    private func mask(_ bits: [UInt64]) -> CGEventMask { bits.reduce(0) { $0 | (1 << $1) } }

    @Test func theMasksSplitPressesFromDragsPressureScrollsAndGestures() {
        #expect(TapEvent.pressMask == mask([1, 2, 3, 4, 25, 26]))
        #expect(TapEvent.gatedMask == mask([6, 7, 22, 27, 29, 30, 34]))
        #expect(TapEvent.pressMask & TapEvent.gatedMask == 0)
        #expect(
            TapEvent.pressMask | TapEvent.gatedMask == mask([1, 2, 3, 4, 6, 7, 22, 25, 26, 27, 29, 30, 34]))
    }

    @Test(arguments: [CGEventType.tapDisabledByTimeout, .tapDisabledByUserInput])
    func theDisabledNoticesAreNeitherListedNorParsed(notice: CGEventType) throws {
        #expect(!TapEvent.pressTypes.contains(notice))
        #expect(!TapEvent.gatedTypes.contains(notice))
        #expect(TapEvent(notice, try event(notice)) == nil)
    }

    @Test func everyListedTypeParsesAndRidesItsPort() throws {
        for type in TapEvent.pressTypes + TapEvent.gatedTypes {
            let parsed = try #require(TapEvent(type, try event(type)), "type \(type.rawValue) is listed but not parsed")
            #expect(parsed.ridesGatedPort == TapEvent.gatedTypes.contains(type), "type \(type.rawValue)")
        }
    }

    private func event(_ type: CGEventType, number: Int64 = 0, button: Int64? = nil) throws -> CGEvent {
        let event = try #require(CGEvent(source: nil))
        event.type = type
        event.setIntegerValueField(DockSwipeFields.hidType, value: DockSwipeFields.dockSwipe)
        event.setIntegerValueField(.mouseEventNumber, value: number)
        if let button { event.setIntegerValueField(.mouseEventButtonNumber, value: button) }
        return event
    }

    @Test(arguments: [
        (CGEventType.leftMouseDown, Int64(41), Int64(0), PointerEvent.press(PressID(button: 0, number: 41))),
        (.leftMouseUp, 41, 0, .release(PressID(button: 0, number: 41))),
        (.rightMouseDown, 42, 1, .press(PressID(button: 1, number: 42))),
        (.rightMouseUp, 42, 1, .release(PressID(button: 1, number: 42))),
        (.otherMouseDown, 43, 3, .press(PressID(button: 3, number: 43))),
        (.otherMouseUp, 43, 3, .release(PressID(button: 3, number: 43))),
        (.leftMouseDragged, 0, 0, .drag(button: 0)),
        (.rightMouseDragged, 0, 1, .drag(button: 1)),
        (.otherMouseDragged, 0, 4, .drag(button: 4)),
    ])
    func parsesPressesReleasesAndDrags(type: CGEventType, number: Int64, button: Int64, expected: PointerEvent) throws {
        #expect(TapEvent(type, try event(type, number: number, button: button)) == .pointer(expected))
    }

    @Test func parsesPressure() throws {
        let type = try #require(CGEventType(rawValue: 34))
        #expect(TapEvent(type, try event(type)) == .pointer(.pressure))
    }

    @Test(arguments: [CGEventType.mouseMoved, .keyDown])
    func ignoresEverythingElse(type: CGEventType) throws {
        #expect(TapEvent(type, try event(type)) == nil)
    }

    private func gesture(_ type: UInt32, hidType: Int64 = DockSwipeFields.dockSwipe, phase: Int64) throws -> CGEvent {
        let event = try #require(CGEvent(source: nil))
        event.type = try #require(CGEventType(rawValue: type))
        event.setIntegerValueField(DockSwipeFields.hidType, value: hidType)
        event.setIntegerValueField(DockSwipeFields.phase, value: phase)
        return event
    }

    @Test(arguments: [
        (Int64(128), DockSwipePhase.mayBegin), (1, .began), (2, .changed), (4, .ended), (8, .cancelled), (0, .changed),
    ])
    func parsesADockSwipeOnEitherGestureTypeWithItsPhase(phase: Int64, expected: DockSwipePhase) throws {
        for (type, stream) in [
            (DockSwipeFields.gestureType, DockSwipeStream.gesture),
            (DockSwipeFields.dockControlType, .dockControl),
        ] {
            let event = try gesture(type, phase: phase)
            #expect(TapEvent(event.type, event) == .dockSwipe(expected, stream))
        }
    }

    @Test(arguments: [Int64(0), 8, 5, 6])
    func ignoresEveryOtherGestureSoPinchRotateAndAppSwipesPass(hidType: Int64) throws {
        let event = try gesture(DockSwipeFields.gestureType, hidType: hidType, phase: 1)
        #expect(TapEvent(event.type, event) == nil)
    }

    @Test func aDroppedDockSwipeReturnsNothingAndAPassedOneComesBackAsIs() throws {
        let event = try gesture(DockSwipeFields.dockControlType, phase: 1)
        #expect(DockSwipeVerdict.drop.apply(to: event) == nil)
        #expect(DockSwipeVerdict.pass.apply(to: event)?.takeUnretainedValue() === event)
    }

    @Test func parsesAScrollEventAsAScroll() throws {
        let scroll = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: 1, wheel2: 0, wheel3: 0))
        scroll.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
        #expect(TapEvent(.scrollWheel, scroll) == .scroll(.fingers(.changed)))
    }

    private func scroll(units: CGScrollEventUnit, phase: Int64 = 0, momentum: Int64 = 0) throws -> CGEvent {
        let event = try #require(
            CGEvent(scrollWheelEvent2Source: nil, units: units, wheelCount: 1, wheel1: 1, wheel2: 0, wheel3: 0))
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum)
        return event
    }

    @Test func aLineUnitEventIsAWheelWhateverItsPhase() throws {
        #expect(ScrollEvent(try scroll(units: .line)) == .wheel)
        #expect(ScrollEvent(try scroll(units: .line, phase: 1)) == .wheel)
    }

    @Test(arguments: [
        (Int64(128), Int64(0), ScrollEvent.fingers(.mayBegin)),
        (1, 0, .fingers(.began)),
        (2, 0, .fingers(.changed)),
        (4, 0, .fingers(.ended)),
        (8, 0, .fingers(.cancelled)),
        (0, 1, .momentum(.began)),
        (0, 2, .momentum(.changed)),
        (0, 3, .momentum(.ended)),
        (0, 0, .unphased),
    ])
    func aPixelUnitEventReadsItsPhases(phase: Int64, momentum: Int64, expected: ScrollEvent) throws {
        #expect(ScrollEvent(try scroll(units: .pixel, phase: phase, momentum: momentum)) == expected)
    }

    private let deltaFields: [CGEventField] = [
        .scrollWheelEventDeltaAxis1, .scrollWheelEventDeltaAxis2, .scrollWheelEventDeltaAxis3,
        .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis3,
        .scrollWheelEventPointDeltaAxis1, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventPointDeltaAxis3,
    ]

    @Test func passStillZeroesEveryDeltaInPlaceAndKeepsTheRest() throws {
        let event = try #require(
            CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 3, wheel1: -7, wheel2: 3, wheel3: 2))
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
        #expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) != 0)
        #expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) != 0)
        #expect(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) != 0)

        let out = try #require(ScrollVerdict.passStill.apply(to: event))

        #expect(out.takeUnretainedValue() === event)
        for field in deltaFields { #expect(event.getDoubleValueField(field) == 0, "field \(field.rawValue)") }
        #expect(event.type == .scrollWheel)
        #expect(event.getIntegerValueField(.scrollWheelEventScrollPhase) == 2)
        #expect(event.getIntegerValueField(.scrollWheelEventIsContinuous) == 1)
    }

    @Test func passKeepsEveryDeltaAndDropReturnsNothing() throws {
        let event = try scroll(units: .pixel, phase: 2)
        let before = deltaFields.map { event.getDoubleValueField($0) }

        let out = try #require(ScrollVerdict.pass.apply(to: event))

        #expect(out.takeUnretainedValue() === event)
        #expect(deltaFields.map { event.getDoubleValueField($0) } == before)
        #expect(ScrollVerdict.drop.apply(to: event) == nil)
    }

    @Test func passAsMoveRewritesADragToAMove() throws {
        let drag = try event(.leftMouseDragged)
        let out = try #require(PointerVerdict.passAsMove.apply(to: drag))
        #expect(out.takeUnretainedValue().type == .mouseMoved)
    }

    @Test func passLeavesTheEventAsItCame() throws {
        let drag = try event(.leftMouseDragged)
        let out = try #require(PointerVerdict.pass.apply(to: drag))
        #expect(out.takeUnretainedValue() === drag)
        #expect(drag.type == .leftMouseDragged)
    }

    @Test func dropReturnsNothing() throws {
        #expect(PointerVerdict.drop.apply(to: try event(.leftMouseDown)) == nil)
    }
}
