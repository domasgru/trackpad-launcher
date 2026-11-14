import AppKit
import LauncherCore
import Testing
@testable import LauncherUI

/// A `ProgressDotsView` put into a borderless window that is never ordered in. The window's on-screen state and Reduce
/// motion are both read from the bench.
@MainActor
final class ProgressDotsBench {
    static let font = NSFont.systemFont(ofSize: 13)

    let view: ProgressDotsView
    let window: NSWindow
    private let state: State

    final class State {
        var reduceMotion: Bool
        var onScreen: Bool
        init(reduceMotion: Bool, onScreen: Bool) {
            self.reduceMotion = reduceMotion
            self.onScreen = onScreen
        }
    }

    init(reduceMotion: Bool = false, onScreen: Bool = true) {
        _ = NSApplication.shared
        let state = State(reduceMotion: reduceMotion, onScreen: onScreen)
        self.state = state
        view = ProgressDotsView(
            font: Self.font, color: .disabledControlTextColor, isOnScreen: { _ in state.onScreen },
            reduceMotion: { state.reduceMotion })
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: .borderless, backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        enter()
    }

    func setReduceMotion(_ on: Bool) { state.reduceMotion = on }
    func setOnScreen(_ on: Bool) { state.onScreen = on }

    func enter() { window.contentView = view }
    func leave() { window.contentView = nil }

    func postDisplayOptionsChange() {
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: NSWorkspace.shared)
    }

    func postOcclusionChange() {
        NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: window)
    }

    var steps: CAKeyframeAnimation? {
        view.maskLayer.animation(forKey: ProgressDotsView.animationKey) as? CAKeyframeAnimation
    }

    var anyAnimation: Bool {
        view.maskLayer.animationKeys()?.isEmpty == false || view.layer?.animationKeys()?.isEmpty == false
    }

    /// The advance of "…" in the bench's font, as AppKit's own text measurement gives it.
    var ellipsisWidth: CGFloat {
        NSAttributedString(string: "…", attributes: [.font: Self.font]).size().width
    }

    var slot: CGFloat { ellipsisWidth / 3 }

    /// The mask's presented width in slots, its layer paused at `time` seconds into the loop. The shipped animation is
    /// re-added to start at layer time zero, which is where a paused layer in a window nobody sees reads its loop from.
    func presentedSlots(at time: Double) throws -> Double {
        let layer = view.maskLayer
        if layer.speed != 0 {
            let shipped = try #require(steps?.copy() as? CAKeyframeAnimation)
            shipped.beginTime = 0.000001
            shipped.fillMode = .both
            layer.speed = 0
            layer.add(shipped, forKey: ProgressDotsView.animationKey)
        }
        layer.timeOffset = time
        CATransaction.flush()
        let presented = try #require(layer.presentation())
        return Double(presented.bounds.width / slot)
    }
}
