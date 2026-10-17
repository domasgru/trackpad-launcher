import CoreGraphics
import Foundation
import LauncherCore
import Synchronization

/// The app's event taps: two active session taps on one `userInteractive` thread. The press port listens for the
/// tap's whole life; the gated port, over drags, pressure, scrolling and the system's gesture events (of which only
/// Dock swipes are acted on), only while `TapFilters` says so, so ordinary pointing and scrolling never reach the app.
/// It exists from the `run` that armed click blocking until the next `run`.
/// Threads: installed and removed on main. The callback, `follow()` and `recover()` run on the tap thread, the only
/// caller of `tapEnable` on the gated port once running. Frame threads only read `holding` and call `wake()`. The
/// thread retains the ClickTap, so no callback outlives the object behind its `userInfo`.
final class ClickTap: Sendable {
    /// Writer: the tap thread. Reader: frame threads (`holding`).
    private let filters = Mutex(TapFilters())
    /// Writer: main (install, remove). The tap thread switches `gated` and re-enables `presses`, under this lock.
    private let ports = Mutex<Unchecked<(presses: CFMachPort, gated: CFMachPort)>?>(nil)
    /// Writer: the tap thread, once, before its first turn. Readers: main (remove), frame threads (`wake`).
    private let runLoop = Mutex<Unchecked<CFRunLoop>?>(nil)
    /// A source whose perform is `follow()`, signalled by frame threads. Signals coalesce; one before the loop runs is
    /// honoured by the first `follow()`. Writer: main, once in `install`, before any frame thread can see the tap.
    private let wakeUp = Mutex<Unchecked<CFRunLoopSource>?>(nil)

    private init() {}

    /// nil when the system refuses either tap (no Accessibility).
    @MainActor static func install() -> ClickTap? {
        let tap = ClickTap()
        let userInfo = Unmanaged.passUnretained(tap).toOpaque()
        guard
            let presses = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: TapEvent.pressMask, callback: clickTapCallback, userInfo: userInfo)
        else { return nil }
        guard
            let gated = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: TapEvent.gatedMask, callback: clickTapCallback, userInfo: userInfo)
        else {
            CFMachPortInvalidate(presses)
            return nil
        }
        CGEvent.tapEnable(tap: gated, enable: false)
        var context = CFRunLoopSourceContext(
            version: 0, info: userInfo, retain: nil, release: nil, copyDescription: nil, equal: nil, hash: nil,
            schedule: nil, cancel: nil,
            perform: { info in
                guard let info else { return }
                Unmanaged<ClickTap>.fromOpaque(info).takeUnretainedValue().follow()
            })
        let source = CFRunLoopSourceCreate(nil, 0, &context)
        tap.ports.withLock { $0 = Unchecked((presses, gated)) }
        tap.wakeUp.withLock { $0 = source.map(Unchecked.init) }
        let thread = Thread { [tap] in
            let loop: CFRunLoop = CFRunLoopGetCurrent()
            let sources = tap.ports.withLock {
                $0.map { ports in
                    [ports.value.presses, ports.value.gated].map { CFMachPortCreateRunLoopSource(nil, $0, 0) }
                }
            }
            for case let source? in sources ?? [] { CFRunLoopAddSource(loop, source, .commonModes) }
            if let wakeUp = tap.wakeUp.withLock({ $0 }) { CFRunLoopAddSource(loop, wakeUp.value, .commonModes) }
            tap.runLoop.withLock { $0 = Unchecked(loop) }
            tap.follow()
            // Without a valid source (removed before this thread started) the run loop returns at once.
            CFRunLoopRun()
        }
        thread.name = "ClickTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        return tap
    }

    /// Frame thread.
    var holding: ClickFilter.Holding { filters.withLock { $0.holding } }

    /// Frame thread, when its trackpad's `wantsTap` flipped. Never waits; a no-op after removal.
    func wake() {
        guard let source = wakeUp.withLock({ $0 }) else { return }
        CFRunLoopSourceSignal(source.value)
        if let loop = runLoop.withLock({ $0 }) { CFRunLoopWakeUp(loop.value) }
    }

    /// Main. Idempotent. Never relies on macOS to stop delivery after a revoke.
    @MainActor func remove() {
        ports.withLock {
            if let ports = $0?.value {
                for port in [ports.presses, ports.gated] {
                    CGEvent.tapEnable(tap: port, enable: false)
                    CFMachPortInvalidate(port)
                }
            }
            $0 = nil
        }
        wakeUp.withLock { $0.map { CFRunLoopSourceInvalidate($0.value) } }
        runLoop.withLock { $0.map { CFRunLoopStop($0.value) } }
    }

    /// Tap thread, also the wake-up source's perform.
    fileprivate func follow() {
        let context = TapContext.estimated(from: mergedBlocking())
        apply(filters.withLock { $0.follow(context) })
    }

    /// Tap thread, on a disabled notice, whether the system's or the echo of our own close: the notice only prompts a
    /// reconcile against what the ports read now. Nothing when the ports are gone.
    private func recover() {
        guard
            let states = ports.withLock({
                $0.map { (presses: CGEvent.tapIsEnabled(tap: $0.value.presses), gated: CGEvent.tapIsEnabled(tap: $0.value.gated)) }
            })
        else { return }
        let context = TapContext.estimated(from: mergedBlocking())
        let change = filters.withLock {
            $0.portsWereDisabled(pressPortIsOn: states.presses, gatedPortIsOn: states.gated, in: context)
        }
        if !states.presses {
            ports.withLock { $0.map { CGEvent.tapEnable(tap: $0.value.presses, enable: true) } }
        }
        apply(change)
    }

    /// Tap thread, after the filters' lock is released.
    private func apply(_ change: GateChange?) {
        guard let change else { return }
        ports.withLock { $0.map { CGEvent.tapEnable(tap: $0.value.gated, enable: change == .open) } }
    }

    /// Tap thread.
    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            recover()
            return .passUnretained(event)
        }
        guard let parsed = TapEvent(type, event) else { return .passUnretained(event) }
        // Read before the filters' lock, so no two locks are held at once.
        let context = TapContext.estimated(from: mergedBlocking())
        let decision = filters.withLock { $0.decide(parsed, in: context) }
        // Before the verdict returns, so the gate is settled for the next event.
        apply(decision.gate)
        return decision.verdict.apply(to: event)
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

extension TapEvent {
    /// The tap's whole vocabulary, in two lists. The masks are built from them, and a test parses one synthetic event
    /// of every listed type, so the tap is never sent a type the parser does not read. Type 34 is
    /// NSEventTypePressure, which has no public CGEventType case but is usable in a mask and as a rewrite target.
    /// Types 29 and 30 are the system's gesture and Dock control events, also without public cases; a Dock swipe may
    /// arrive as either. There are no keyboard or plain-move types.
    static let pressTypes: [CGEventType] = [
        .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
    ]
    static let gatedTypes: [CGEventType] = [
        .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, CGEventType(rawValue: 34)!, .scrollWheel,
        CGEventType(rawValue: DockSwipeFields.gestureType)!, CGEventType(rawValue: DockSwipeFields.dockControlType)!,
    ]
    static var pressMask: CGEventMask { mask(pressTypes) }
    static var gatedMask: CGEventMask { mask(gatedTypes) }

    private static func mask(_ types: [CGEventType]) -> CGEventMask {
        types.reduce(0) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
    }

    init?(_ type: CGEventType, _ event: CGEvent) {
        if type == .scrollWheel {
            self = .scroll(ScrollEvent(event))
        } else if type.rawValue == DockSwipeFields.gestureType || type.rawValue == DockSwipeFields.dockControlType {
            guard let phase = DockSwipePhase(event) else { return nil }
            let stream: DockSwipeStream = type.rawValue == DockSwipeFields.gestureType ? .gesture : .dockControl
            self = .dockSwipe(phase, stream)
        } else if let pointer = PointerEvent(type, event) {
            self = .pointer(pointer)
        } else {
            return nil
        }
    }
}

/// The undocumented event-system numbers a Dock swipe is read by. None has a public CGEventField or CGEventType case.
enum DockSwipeFields {
    /// NSEventTypeGesture.
    static let gestureType: UInt32 = 29
    /// The Dock's own control event, which carries the swipe it acts on.
    static let dockControlType: UInt32 = 30
    /// The gesture's IOHIDEventType.
    static let hidType = CGEventField(rawValue: 110)!
    /// kIOHIDEventTypeDockSwipe.
    static let dockSwipe: Int64 = 23
    /// The gesture's phase, in IOHIDEventPhase bits.
    static let phase = CGEventField(rawValue: 132)!
}

extension DockSwipePhase {
    /// nil unless the event is a Dock swipe. Phase bits: began 1, changed 2, ended 4, cancelled 8, mayBegin 128.
    /// A Dock swipe with an unknown phase reads as `.changed`, which the filter never starts a drop on.
    init?(_ event: CGEvent) {
        guard event.getIntegerValueField(DockSwipeFields.hidType) == DockSwipeFields.dockSwipe else { return nil }
        switch event.getIntegerValueField(DockSwipeFields.phase) {
        case 128: self = .mayBegin
        case 1: self = .began
        case 4: self = .ended
        case 8: self = .cancelled
        default: self = .changed
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

extension TapVerdict {
    func apply(to event: CGEvent) -> Unmanaged<CGEvent>? {
        switch self {
        case .pointer(let verdict): verdict.apply(to: event)
        case .scroll(let verdict): verdict.apply(to: event)
        case .dockSwipe(let verdict): verdict.apply(to: event)
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

extension DockSwipeVerdict {
    func apply(to event: CGEvent) -> Unmanaged<CGEvent>? { self == .drop ? nil : .passUnretained(event) }
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
