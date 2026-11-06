import AppKit
@testable import LauncherUI

/// A `GearView` put into a borderless window that is never ordered in; setting the content view is what moves it in.
@MainActor
final class GearBench {
    let view: GearView
    let window: NSWindow

    init(reduceMotion: Bool) {
        _ = NSApplication.shared
        let reader = ReduceMotionReader(reduceMotion)
        self.reader = reader
        view = GearView(image: nil, reduceMotion: { reader.value })
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: .borderless, backing: .buffered,
            defer: true)
        window.isReleasedWhenClosed = false
        enter()
    }

    final class ReduceMotionReader {
        var value: Bool
        init(_ value: Bool) { self.value = value }
    }

    private let reader: ReduceMotionReader

    func setReduceMotion(_ on: Bool) {
        reader.value = on
    }

    func enter() { window.contentView = view }
    func leave() { window.contentView = nil }

    func postDisplayOptionsChange() {
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: NSWorkspace.shared)
    }

    var turn: CABasicAnimation? { view.gearLayer.animation(forKey: GearView.animationKey) as? CABasicAnimation }

    var anyAnimation: Bool {
        view.gearLayer.animationKeys()?.isEmpty == false || view.layer?.animationKeys()?.isEmpty == false
    }
}
