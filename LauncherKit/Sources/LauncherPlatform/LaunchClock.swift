import AppKit
import QuartzCore

/// The clock of one watched launch: a zero-size layer in a one-point window that is never ordered in, and deadlines that
/// are 1→1 opacity animations on it, so time passes on the render server's clock. Made with the launch's watch,
/// stopped with it; the layer goes when it stops, and the window closes with the last clock.
@MainActor final class LaunchClock {
    /// The window every clock's layer lives in. Layers need a window for their animations to run: an animation on a
    /// detached layer stops at once. Made with the first clock, closed with the last.
    private(set) static var hostPanel: NSPanel?
    private static var clockCount = 0
    private static var deadlineCount = 0

    private let layer = CALayer()
    private var deadlines: [Deadline] = []
    private var isStopped = false

    init() {
        let panel = Self.hostPanel ?? Self.makeHost()
        Self.hostPanel = panel
        Self.clockCount += 1
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.contentView?.layer?.addSublayer(layer)
        CATransaction.commit()
    }

    isolated deinit { stop() }

    /// Calls `passed` once `wait` has passed on the render server's clock, unless the clock has stopped by then.
    func after(_ wait: Duration, _ passed: @escaping @MainActor () -> Void) {
        guard !isStopped else { return }
        let deadline = Deadline { [weak self] in
            guard let self else { return }
            self.deadlines.removeAll { $0.isCancelled || $0.hasPassed }
            passed()
        }
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = Float(1)
        animation.toValue = Float(1)
        animation.duration = wait.seconds
        animation.delegate = deadline
        Self.deadlineCount += 1
        deadlines.append(deadline)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.add(animation, forKey: "deadline-\(Self.deadlineCount)")
        CATransaction.commit()
    }

    /// Cancels every deadline, then removes the layer: a removed layer's animations stop early. Idempotent.
    func stop() {
        guard !isStopped else { return }
        isStopped = true
        deadlines.forEach { $0.isCancelled = true }
        deadlines = []
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.removeAllAnimations()
        layer.removeFromSuperlayer()
        CATransaction.commit()
        Self.clockCount -= 1
        if Self.clockCount == 0 {
            Self.hostPanel?.close()
            Self.hostPanel = nil
        }
    }

    private static func makeHost() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1), styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.canHide = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        content.wantsLayer = true
        panel.contentView = content
        return panel
    }

    /// A deadline on the render server's clock. A cancelled one reports nothing. A stop the system causes
    /// (`finished == false`, not cancelled) reports as passed, so no launch can outlive its cap. Internal, so a test can
    /// drive its stop rule directly.
    @MainActor final class Deadline: NSObject, CAAnimationDelegate {
        var isCancelled = false
        private(set) var hasPassed = false
        let passed: @MainActor () -> Void
        init(passed: @escaping @MainActor () -> Void) { self.passed = passed }
        nonisolated func animationDidStop(_ animation: CAAnimation, finished: Bool) {
            MainActor.assumeIsolated {
                guard !isCancelled else { return }
                hasPassed = true
                passed()
            }
        }
    }
}

extension Duration {
    /// Whole and fractional seconds.
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
