import CoreGraphics
import LauncherCore
import Testing

@testable import LauncherPlatform

@Suite struct PointerEventTests {
    @Test func maskCoversPressesTheirReleasesDragsAndPressureOnly() {
        let bits: [UInt64] = [1, 2, 3, 4, 6, 7, 25, 26, 27, 34]
        #expect(PointerEvent.tapMask == bits.reduce(0) { $0 | (1 << $1) })
    }

    @Test func everyMaskedTypeParses() throws {
        for type in PointerEvent.tapTypes {
            #expect(PointerEvent(type, try event(type)) != nil, "type \(type.rawValue) is in the mask but not parsed")
        }
    }

    private func event(_ type: CGEventType, number: Int64 = 0, button: Int64? = nil) throws -> CGEvent {
        let event = try #require(CGEvent(source: nil))
        event.type = type
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
        #expect(PointerEvent(type, try event(type, number: number, button: button)) == expected)
    }

    @Test func parsesPressure() throws {
        let type = try #require(CGEventType(rawValue: 34))
        #expect(PointerEvent(type, try event(type)) == .pressure)
    }

    @Test(arguments: [CGEventType.mouseMoved, .scrollWheel, .keyDown])
    func ignoresEverythingElse(type: CGEventType) throws {
        #expect(PointerEvent(type, try event(type)) == nil)
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
