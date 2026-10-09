import LauncherCore
import Testing

@testable import LauncherPlatform

@Suite struct TouchFrameParsingTests {
    @Test func mirrorMatchesTheFrameworksTouchStride() {
        #expect(MemoryLayout<MTTouchMirror>.stride == 96)
    }

    @Test func keepsOnlyContactsThatAreDownAndFlipsTheOrigin() {
        var buffer = [
            MTTouchMirror(identifier: 7, state: 3, x: 0.1, y: 0.9),
            MTTouchMirror(identifier: 8, state: 4, x: 0.5, y: 0.5),
            MTTouchMirror(identifier: 9, state: 2, x: 0.3, y: 0.3),
            MTTouchMirror(identifier: 10, state: 5, x: 0.4, y: 0.4),
        ]
        let frame = buffer.withUnsafeMutableBytes {
            TouchFrame(parsing: $0.baseAddress, count: 4, timestamp: 12.5, press: nil)
        }

        #expect(frame.time.seconds == 12.5)
        #expect(frame.press == nil)
        #expect(frame.touches.map(\.id.rawValue) == [7, 8])
        #expect(frame.touches.map(\.phase) == [.landing, .down])
        #expect(frame.touches.map(\.position.x) == [Double(Float(0.1)), 0.5])
        #expect(frame.touches[0].position.y == 1 - Double(Float(0.9)))
        #expect(frame.touches[1].position.y == 0.5)
    }

    @Test func emptyFrameHasNoTouches() {
        let frame = TouchFrame(parsing: nil, count: 0, timestamp: 1, press: .click)
        #expect(frame.touches.isEmpty)
        #expect(frame.press == .click)
    }
}
