import AppKit
@testable import LauncherUI

/// An `UpdatePictureView` put into a borderless window that is never ordered in; setting the content view moves it in.
/// The window's on-screen state and Reduce motion are both read from the bench.
@MainActor
final class UpdatePictureBench {
    let view: UpdatePictureView
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
        view = UpdatePictureView(
            tray: nil, arrow: nil, isOnScreen: { _ in state.onScreen }, reduceMotion: { state.reduceMotion })
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: .borderless, backing: .buffered,
            defer: true)
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

    var arrowDrift: CAKeyframeAnimation? {
        view.arrowLayer.animation(forKey: UpdatePictureView.animationKey) as? CAKeyframeAnimation
    }

    var maskDrift: CAKeyframeAnimation? {
        view.maskLayer.animation(forKey: UpdatePictureView.animationKey) as? CAKeyframeAnimation
    }

    var anyAnimation: Bool {
        [view.arrowLayer, view.maskLayer, view.trayLayer].contains { $0.animationKeys()?.isEmpty == false }
            || view.layer?.animationKeys()?.isEmpty == false
    }
}
