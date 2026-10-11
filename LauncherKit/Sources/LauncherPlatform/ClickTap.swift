import CoreGraphics
import Foundation
import LauncherCore
import Synchronization

/// The app's one event tap: an active session tap over mouse buttons, drags, pressure and scrolling only.
/// It exists from the `run` that armed click blocking until the next `run`.
/// Threads: installed and removed on main. Its callback runs on the tap's own `userInteractive` thread, whose run loop
/// holds only this tap's source and ends when the tap is removed. That thread retains the ClickTap, so no callback
/// outlives the object behind its `userInfo`.
final class ClickTap: Sendable {
    /// Writer: the tap thread. Reader: frame threads.
    private let filter = Mutex(ClickFilter())
    /// Writer and reader: the tap thread.
    private let scrollFilter = Mutex(ScrollFilter())
    /// Writer: main (install, remove). The tap thread only re-enables.
    private let port = Mutex<Unchecked<CFMachPort>?>(nil)
    /// Set by the tap thread; main stops it on remove.
    private let runLoop = Mutex<Unchecked<CFRunLoop>?>(nil)

    /// nil when the system refuses the tap (no Accessibility).
    @MainActor static func install() -> ClickTap? {
        let tap = ClickTap()
        guard
            let machPort = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: TapEvent.tapMask, callback: clickTapCallback,
                userInfo: Unmanaged.passUnretained(tap).toOpaque())
        else { return nil }
        tap.port.withLock { $0 = Unchecked(machPort) }
        let thread = Thread { [tap] in
            let loop: CFRunLoop = CFRunLoopGetCurrent()
            let source = tap.port.withLock { $0.map { CFMachPortCreateRunLoopSource(nil, $0.value, 0) } }
            if let source { CFRunLoopAddSource(loop, source, .commonModes) }
            tap.runLoop.withLock { $0 = Unchecked(loop) }
            // Without a source (removed before this thread started) the run loop returns at once.
            CFRunLoopRun()
        }
        thread.name = "ClickTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        return tap
    }

    /// Frame thread.
    var holding: ClickFilter.Holding { filter.withLock { $0.holding } }

    /// Main. Idempotent. Never relies on macOS to stop delivery after a revoke.
    @MainActor func remove() {
        port.withLock {
            if let port = $0?.value {
                CGEvent.tapEnable(tap: port, enable: false)
                CFMachPortInvalidate(port)
            }
            $0 = nil
        }
        runLoop.withLock { $0.map { CFRunLoopStop($0.value) } }
    }

    /// Tap thread.
    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Releases and scroll phases may have passed while the tap was disabled.
            filter.withLock { $0.forgetHeldPresses() }
            scrollFilter.withLock { $0.forgetGesture() }
            port.withLock { $0.map { CGEvent.tapEnable(tap: $0.value, enable: true) } }
            return .passUnretained(event)
        }
        guard let parsed = TapEvent(type, event) else { return .passUnretained(event) }
        // Read once, before either filter lock, so no two locks are held at once.
        let blocking = anyTrackpadBlocksClicks()
        switch parsed {
        case .pointer(let pointer):
            return filter.withLock { $0.decide(pointer, trackpadBlocking: blocking) }.apply(to: event)
        case .scroll(let scroll):
            return scrollFilter.withLock { $0.decide(scroll, trackpadBlocking: blocking) }.apply(to: event)
        }
    }
}

/// CoreFoundation references are thread-safe but not annotated Sendable.
private struct Unchecked<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

private let clickTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return .passUnretained(event) }
    return Unmanaged<ClickTap>.fromOpaque(userInfo).takeUnretainedValue().handle(type, event)
}

/// Everything the tap is told about, parsed. `PointerEvent` keeps its vocabulary: a press and what belongs to it.
enum TapEvent: Equatable {
    case pointer(PointerEvent)
    case scroll(ScrollEvent)

    /// The tap's whole vocabulary. The mask is built from this list, and a test parses one synthetic event of every
    /// listed type, so the tap is never sent a type the parser does not read. Type 34 is NSEventTypePressure, which
    /// has no public CGEventType case but is usable in a mask and as a rewrite target.
    /// There are no keyboard or plain-move types.
    static let tapTypes: [CGEventType] = [
        .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
        .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, CGEventType(rawValue: 34)!, .scrollWheel,
    ]
    static var tapMask: CGEventMask { tapTypes.reduce(0) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) } }

    init?(_ type: CGEventType, _ event: CGEvent) {
        if type == .scrollWheel {
            self = .scroll(ScrollEvent(event))
        } else if let pointer = PointerEvent(type, event) {
            self = .pointer(pointer)
        } else {
            return nil
        }
    }
}

extension PointerEvent {
    /// The button comes from the type for left and right, and from `mouseEventButtonNumber` for other buttons.
    /// The number comes from `mouseEventNumber`.
    init?(_ type: CGEventType, _ event: CGEvent) {
        let number = event.getIntegerValueField(.mouseEventNumber)
        let other = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        switch type.rawValue {
        case CGEventType.leftMouseDown.rawValue: self = .press(PressID(button: 0, number: number))
        case CGEventType.leftMouseUp.rawValue: self = .release(PressID(button: 0, number: number))
        case CGEventType.rightMouseDown.rawValue: self = .press(PressID(button: 1, number: number))
        case CGEventType.rightMouseUp.rawValue: self = .release(PressID(button: 1, number: number))
        case CGEventType.otherMouseDown.rawValue: self = .press(PressID(button: other, number: number))
        case CGEventType.otherMouseUp.rawValue: self = .release(PressID(button: other, number: number))
        case CGEventType.leftMouseDragged.rawValue: self = .drag(button: 0)
        case CGEventType.rightMouseDragged.rawValue: self = .drag(button: 1)
        case CGEventType.otherMouseDragged.rawValue: self = .drag(button: other)
        case 34: self = .pressure
        default: return nil
        }
    }
}

extension ScrollEvent {
    /// A line-unit event is a wheel whatever its phases. A continuous one with a scroll phase is fingers on a surface;
    /// with a momentum phase instead, the coasting after the lift; with neither, it stands alone.
    /// Values: CGScrollPhase began 1, changed 2, ended 4, cancelled 8, mayBegin 128; CGMomentumScrollPhase begin 1,
    /// continuous 2, end 3.
    init(_ event: CGEvent) {
        guard event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 else {
            self = .wheel
            return
        }
        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        switch (phase, momentum) {
        case (128, _): self = .fingers(.mayBegin)
        case (1, _): self = .fingers(.began)
        case (2, _): self = .fingers(.changed)
        case (4, _): self = .fingers(.ended)
        case (8, _): self = .fingers(.cancelled)
        case (0, 1): self = .momentum(.began)
        case (0, 2): self = .momentum(.changed)
        case (0, 3): self = .momentum(.ended)
        default: self = .unphased
        }
    }
}

extension PointerVerdict {
    /// `.passAsMove` rewrites the event's type to `.mouseMoved` and passes it on.
    func apply(to event: CGEvent) -> Unmanaged<CGEvent>? {
        switch self {
        case .pass: return .passUnretained(event)
        case .drop: return nil
        case .passAsMove:
            event.type = .mouseMoved
            return .passUnretained(event)
        }
    }
}

extension ScrollVerdict {
    /// `.passStill` zeroes every delta field in place and passes the event, so the app's gesture closes cleanly with
    /// nothing moving. Nothing is ever posted.
    func apply(to event: CGEvent) -> Unmanaged<CGEvent>? {
        switch self {
        case .pass: return .passUnretained(event)
        case .drop: return nil
        case .passStill:
            for field in [CGEventField.scrollWheelEventDeltaAxis1, .scrollWheelEventDeltaAxis2, .scrollWheelEventDeltaAxis3] {
                event.setIntegerValueField(field, value: 0)
            }
            for field in [
                CGEventField.scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis2,
                .scrollWheelEventFixedPtDeltaAxis3, .scrollWheelEventPointDeltaAxis1, .scrollWheelEventPointDeltaAxis2,
                .scrollWheelEventPointDeltaAxis3,
            ] {
                event.setDoubleValueField(field, value: 0)
            }
            return .passUnretained(event)
        }
    }
}
