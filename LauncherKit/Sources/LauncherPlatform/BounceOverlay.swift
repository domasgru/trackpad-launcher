import AppKit
import LauncherCore
import QuartzCore

/// Shows launch bounces. Every bouncing icon sits in one row above the pointer, in one display-sized click-through
/// panel on the pointer's display. Core Animation plays the bounce. Each bounce carries its own deadlines (1→1 opacity
/// animations on its clock layer), which pass on the render server's clock and die with the bounce. An ending lifts
/// the icon out of the row into its own panel. Once the row is empty and the last ending's completion has run, nothing
/// of ours runs.
@MainActor final class BounceOverlay {
    private let flights: LaunchOverlay
    /// The pointer and the displays, read at each start. `ScreenRead.now` in the app.
    private let screen: @MainActor () -> ScreenRead
    /// Oldest first: the row's order, newest on the right.
    private var row: [Bouncing] = []
    /// The row's panel and the display it covers; nil while the row is empty.
    private var stage: (panel: NSPanel, host: CALayer, display: LaunchDisplay)?
    /// Quiet-fade panels, kept until their fade's completion (AppKit keeps closed panels in its window list).
    private var fading: Set<NSPanel> = []
    private var deadlineCount = 0

    private struct Bouncing {
        let app: AppEntry
        /// `LaunchTuning.current` when it started: the tuner restores its override right after a preview.
        let tuning: LaunchTuning
        let reduceMotion: Bool
        /// Positioned at the icon's rest.
        let slot: CALayer
        /// Anchor at its bottom centre; plays `BounceMotion` forever.
        let icon: CALayer
        /// Zero-size; carries the deadlines.
        let clock: CALayer
        var deadlines: [Deadline]
        /// Called once, by the first deadline to pass; nil after.
        var ranOut: (@MainActor () -> Void)?
    }

    init(flights: LaunchOverlay, screen: @escaping @MainActor () -> ScreenRead) {
        self.flights = flights
        self.screen = screen
    }

    func start(_ app: AppEntry, cap: Duration, ranOut: @escaping @MainActor () -> Void) {
        guard !row.contains(where: { $0.app.bundleID == app.bundleID }) else { return }
        let tuning = LaunchTuning.current
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || tuning.forceReduceMotion
        let read = screen()
        let side = CGFloat(tuning.iconSide)
        let before = stage?.display
        guard let layout = BounceRow(
                count: row.count + 1, pointer: read.pointer, among: read.displays, side: side, tuning: tuning.bounce),
              let stage = stage(on: layout.display)
        else {
            Task { @MainActor in ranOut() }
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let origin = layout.display.frame.origin
        let rest = layout.rests[layout.rests.count - 1]

        let slot = CALayer()
        slot.position = CGPoint(x: rest.x - origin.x, y: rest.y - origin.y)
        let icon = CALayer()
        icon.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        icon.anchorPoint = CGPoint(x: 0.5, y: 0)
        icon.position = .zero
        icon.contents = flights.bitmap(for: app, scale: layout.display.scale)
        icon.contentsScale = layout.display.scale
        icon.minificationFilter = .trilinear
        icon.allowsEdgeAntialiasing = true
        for animation in BounceMotion(tuning: tuning.bounce, reduceMotion: reduceMotion).animations() {
            guard let keyPath = animation.keyPath else { continue }
            icon.add(animation, forKey: keyPath)
        }
        let clock = CALayer()
        slot.addSublayer(icon)
        slot.addSublayer(clock)

        let id = app.bundleID
        var bouncing = Bouncing(
            app: app, tuning: tuning, reduceMotion: reduceMotion, slot: slot, icon: icon, clock: clock, deadlines: [],
            ranOut: ranOut)
        bouncing.deadlines.append(deadline(on: clock, after: cap) { [weak self] in self?.runOut(id) })
        stage.host.addSublayer(slot)
        let others = row
        row.append(bouncing)
        flow(others, to: Array(layout.rests.dropLast()), on: layout.display, from: before, slides: tuning.bounce.slide)
        CATransaction.commit()
    }

    func limit(_ app: BundleID, to limit: Duration) {
        guard let index = row.firstIndex(where: { $0.app.bundleID == app }) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let clock = row[index].clock
        let added = deadline(on: clock, after: limit) { [weak self] in self?.runOut(app) }
        row[index].deadlines.append(added)
        CATransaction.commit()
    }

    func end(_ app: BundleID, with ending: LaunchBounceEnding) {
        guard let index = row.firstIndex(where: { $0.app.bundleID == app }) else { return }
        let bouncing = row.remove(at: index)
        // Before the layer leaves: removing an animated layer stops its deadlines at the next commit.
        bouncing.deadlines.forEach { $0.isCancelled = true }
        let read = screen()
        let display = stage?.display
        let side = CGFloat(bouncing.tuning.iconSide)

        let slot = bouncing.slot.presentation() ?? bouncing.slot
        let icon = bouncing.icon.presentation() ?? bouncing.icon
        let origin = display?.frame.origin ?? .zero
        let rest = CGPoint(x: slot.position.x + origin.x, y: slot.position.y + origin.y)
        let transform = CATransform3DGetAffineTransform(icon.transform)
        let frame = CGRect(x: -side / 2, y: 0, width: side, height: side).applying(transform)
            .offsetBy(dx: rest.x, dy: rest.y)
        let opacity = icon.opacity

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        switch ending {
        case .launchAnimation:
            flights.play(for: bouncing.app, from: CGPoint(x: frame.midX, y: frame.midY), among: read.displays)
        case .quietFade:
            if let display {
                fade(bouncing, from: frame, rest: rest, transform: icon.transform, opacity: opacity, on: display)
            }
        }
        bouncing.slot.removeFromSuperlayer()
        if let last = row.last,
           let layout = BounceRow(
            count: row.count, pointer: read.pointer, among: read.displays, side: CGFloat(last.tuning.iconSide),
            tuning: last.tuning.bounce),
           let moved = self.stage(on: layout.display) {
            flow(row, to: layout.rests, on: moved.display, from: display, slides: last.tuning.bounce.slide)
        }
        if row.isEmpty {
            stage?.panel.close()
            stage = nil
        }
        CATransaction.commit()
    }

    #if DEBUG
    /// Bounces `app` at the pointer for `duration`, then ends it as a window showing would.
    func preview(_ app: AppEntry, for duration: Duration) {
        start(app, cap: duration) { [weak self] in self?.end(app.bundleID, with: .launchAnimation) }
    }
    #endif

    private func runOut(_ app: BundleID) {
        guard let index = row.firstIndex(where: { $0.app.bundleID == app }), let ranOut = row[index].ranOut else { return }
        row[index].ranOut = nil
        ranOut()
    }

    /// The row's panel on `display`: made and ordered in when the row has none, re-framed when it is on another display.
    private func stage(on display: LaunchDisplay) -> (panel: NSPanel, host: CALayer, display: LaunchDisplay)? {
        if let current = stage {
            guard current.display != display else { return current }
            current.panel.setFrame(display.frame, display: false)
            stage = (current.panel, current.host, display)
            return stage
        }
        guard case let (panel, host)? = LaunchOverlay.makePanel(frame: display.frame) else { return nil }
        panel.orderFrontRegardless()
        stage = (panel, host, display)
        return stage
    }

    /// Moves each icon of `bouncing` to its new rest. Those that move on the same display slide there; a display
    /// change has no slide, because the panel itself moved.
    private func flow(
        _ bouncing: [Bouncing], to rests: [CGPoint], on display: LaunchDisplay, from before: LaunchDisplay?,
        slides duration: Double
    ) {
        let origin = display.frame.origin
        for (item, rest) in zip(bouncing, rests) {
            let new = CGPoint(x: rest.x - origin.x, y: rest.y - origin.y)
            let old = item.slot.position
            item.slot.position = new
            guard before == display, let slide = BounceRow.slide(from: old, to: new, over: duration) else { continue }
            item.slot.add(slide, forKey: "slide")
        }
    }

    private func fade(
        _ bouncing: Bouncing, from frame: CGRect, rest: CGPoint, transform: CATransform3D, opacity: Float,
        on display: LaunchDisplay
    ) {
        let visible = frame.intersection(display.frame)
        guard !visible.isEmpty, case let (panel, host)? = LaunchOverlay.makePanel(frame: visible) else { return }
        fading.insert(panel)
        panel.orderFrontRegardless()

        let side = CGFloat(bouncing.tuning.iconSide)
        let frozen = CALayer()
        frozen.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        frozen.anchorPoint = CGPoint(x: 0.5, y: 0)
        frozen.position = CGPoint(x: rest.x - visible.minX, y: rest.y - visible.minY)
        frozen.transform = transform
        frozen.opacity = 0
        frozen.contents = bouncing.icon.contents
        frozen.contentsScale = display.scale
        frozen.minificationFilter = .trilinear
        frozen.allowsEdgeAntialiasing = true
        host.addSublayer(frozen)

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            MainActor.assumeIsolated {
                panel.close()
                self?.fading.remove(panel)
            }
        }
        let motion = BounceMotion(tuning: bouncing.tuning.bounce, reduceMotion: bouncing.reduceMotion)
        frozen.add(motion.quietFade(from: opacity), forKey: "fade")
        CATransaction.commit()
    }

    /// One deadline on `clock`: a 1→1 opacity animation of `duration`, whose stop is the push.
    private func deadline(
        on clock: CALayer, after duration: Duration, passed: @escaping @MainActor () -> Void
    ) -> Deadline {
        let deadline = Deadline(passed: passed)
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = Float(1)
        animation.toValue = Float(1)
        animation.duration = duration.seconds
        animation.delegate = deadline
        deadlineCount += 1
        clock.add(animation, forKey: "deadline-\(deadlineCount)")
        return deadline
    }

    /// A deadline on the render server's clock. A cancelled one reports nothing. A stop the system causes
    /// (`finished == false`, not cancelled) reports as passed, so no bounce can outlive its cap. Internal, so a test can
    /// drive its stop rule directly.
    @MainActor final class Deadline: NSObject, CAAnimationDelegate {
        var isCancelled = false
        let passed: @MainActor () -> Void
        init(passed: @escaping @MainActor () -> Void) { self.passed = passed }
        nonisolated func animationDidStop(_ animation: CAAnimation, finished: Bool) {
            MainActor.assumeIsolated { if !isCancelled { passed() } }
        }
    }
}

extension Duration {
    /// Whole and fractional seconds.
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
