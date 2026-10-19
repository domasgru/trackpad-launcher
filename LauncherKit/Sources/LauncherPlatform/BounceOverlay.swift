import AppKit
import LauncherCore
import QuartzCore

/// Shows launch bounces. Every bouncing icon sits in one row above the pointer, in one display-sized click-through
/// panel on the pointer's display. Core Animation plays the bounce. Each bounce carries its own deadlines (1→1 opacity
/// animations on its clock layer), which pass on the render server's clock and die with the bounce. An ending lifts
/// the icon out of the row into its own panel. Once the row is empty and the last ending's completion has run, nothing
/// of ours runs.
@MainActor final class BounceOverlay {
    private let launchOverlay: LaunchOverlay
    /// The pointer and the displays, read at each start. `ScreenRead.now` in the app.
    private let screen: @MainActor () -> ScreenRead
    /// Oldest first: the row's order, newest on the right.
    private var row: [Bouncing] = []
    /// The row's panel and the display it covers; nil while the row is empty.
    private var stage: RowStage?
    /// Quiet-fade panels, kept until their fade's completion (AppKit keeps closed panels in its window list).
    private var fading: Set<NSPanel> = []
    private var deadlineCount = 0
    /// The pointer-move monitors, which exist only while the row is not empty.
    private var monitors: [Any] = []

    private struct RowStage {
        let panel: NSPanel
        let host: CALayer
        let display: LaunchDisplay
    }

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

    init(launchOverlay: LaunchOverlay, screen: @escaping @MainActor () -> ScreenRead) {
        self.launchOverlay = launchOverlay
        self.screen = screen
    }

    func start(_ app: AppEntry, cap: Duration, ranOut: @escaping @MainActor () -> Void) {
        guard !row.contains(where: { $0.app.bundleID == app.bundleID }) else { return }
        let tuning = LaunchTuning.current
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || tuning.forceReduceMotion
        let read = screen()
        let side = CGFloat(tuning.iconSide)
        let before = stage?.display
        guard let layout = Self.layout(count: row.count + 1, read, tuning),
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
        slot.position = Self.position(of: rest, from: origin)
        let icon = Self.iconLayer(
            side: side, contents: launchOverlay.bitmap(for: app, scale: layout.display.scale),
            scale: layout.display.scale)
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
        if row.count == 1 { follow() }
        settle(others, to: Array(layout.rests.dropLast()), on: layout.display, from: before, tuning: tuning.bounce)
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
            launchOverlay.play(for: bouncing.app, from: CGPoint(x: frame.midX, y: frame.midY), among: read.displays)
        case .quietFade:
            if let display {
                fade(bouncing, from: frame, rest: rest, transform: icon.transform, opacity: opacity, on: display)
            }
        }
        bouncing.slot.removeFromSuperlayer()
        if let last = row.last,
           let layout = Self.layout(count: row.count, read, last.tuning),
           let moved = self.stage(on: layout.display) {
            settle(row, to: layout.rests, on: moved.display, from: display, tuning: last.tuning.bounce)
        }
        if row.isEmpty {
            unfollow()
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

    /// Keeps the row above the pointer: passive monitors of moves and drags, read only while a bounce shows. The global
    /// one does not see events sent to our own windows, so the local one covers those.
    private func follow() {
        guard monitors.isEmpty else { return }
        let kinds: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        let global = NSEvent.addGlobalMonitorForEvents(matching: kinds) { [weak self] _ in
            MainActor.assumeIsolated { self?.moved() }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: kinds) { [weak self] event in
            MainActor.assumeIsolated { self?.moved() }
            return event
        }
        monitors = [global, local].compactMap { $0 }
    }

    private func unfollow() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
    }

    /// Re-places the row under the pointer, on the pointer's display. Ended icons are in their own panels and stay out.
    private func moved() {
        guard let last = row.last else { return }
        let read = screen()
        guard let layout = Self.layout(count: row.count, read, last.tuning),
              let before = stage?.display
        else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        guard stage(on: layout.display) != nil else {
            CATransaction.commit()
            return
        }
        let changed = before != layout.display
        let origin = layout.display.frame.origin
        let trailing = last.tuning.bounce.trailing
        for (item, rest) in zip(row, layout.rests) {
            let new = Self.position(of: rest, from: origin)
            if changed { item.slot.removeAnimation(forKey: "trail") }
            if trailing > 0, !changed, item.slot.position != new {
                let from = item.slot.presentation()?.position ?? item.slot.position
                item.slot.position = new
                let trail = CABasicAnimation(keyPath: "position")
                trail.fromValue = NSValue(point: from)
                trail.toValue = NSValue(point: new)
                trail.duration = trailing
                trail.timingFunction = CAMediaTimingFunction(name: .easeOut)
                item.slot.add(trail, forKey: "trail")
            } else {
                item.slot.position = new
                if trailing == 0 { item.slot.removeAnimation(forKey: "trail") }
            }
        }
        CATransaction.commit()
    }

    /// Where the row rests for this read, from the newest bounce's tuning.
    private static func layout(count: Int, _ read: ScreenRead, _ tuning: LaunchTuning) -> BounceRow? {
        BounceRow(
            count: count, pointer: read.pointer, among: read.displays, side: CGFloat(tuning.iconSide),
            tuning: tuning.bounce)
    }

    /// A global rest in the coordinates of a panel whose frame starts at `origin`.
    private static func position(of rest: CGPoint, from origin: CGPoint) -> CGPoint {
        CGPoint(x: rest.x - origin.x, y: rest.y - origin.y)
    }

    /// An icon's layer, anchored at its bottom centre.
    private static func iconLayer(side: CGFloat, contents: Any?, scale: CGFloat) -> CALayer {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        layer.anchorPoint = CGPoint(x: 0.5, y: 0)
        layer.contents = contents
        layer.contentsScale = scale
        layer.minificationFilter = .trilinear
        layer.allowsEdgeAntialiasing = true
        return layer
    }

    /// The row's panel on `display`: made and ordered in when the row has none. When it is on another display it is
    /// re-framed and every icon in the row takes that display's scale and bitmap.
    private func stage(on display: LaunchDisplay) -> RowStage? {
        if let current = stage {
            guard current.display != display else { return current }
            current.panel.setFrame(display.frame, display: false)
            for item in row {
                item.icon.contentsScale = display.scale
                item.icon.contents = launchOverlay.bitmap(for: item.app, scale: display.scale)
            }
            stage = RowStage(panel: current.panel, host: current.host, display: display)
            return stage
        }
        guard case let (panel, host)? = LaunchOverlay.makePanel(frame: display.frame) else { return nil }
        panel.orderFrontRegardless()
        stage = RowStage(panel: panel, host: host, display: display)
        return stage
    }

    /// Moves each icon of `bouncing` to its new rest. Those that move on the same display slide there; a display
    /// change has no slide, because the panel itself moved.
    private func settle(
        _ bouncing: [Bouncing], to rests: [CGPoint], on display: LaunchDisplay, from before: LaunchDisplay?,
        tuning: LaunchTuning.Bounce
    ) {
        let origin = display.frame.origin
        for (item, rest) in zip(bouncing, rests) {
            let new = Self.position(of: rest, from: origin)
            let old = item.slot.position
            item.slot.position = new
            guard before == display, let slide = BounceRow.slide(from: old, to: new, tuning: tuning) else { continue }
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
        let frozen = Self.iconLayer(side: side, contents: bouncing.icon.contents, scale: display.scale)
        frozen.position = Self.position(of: rest, from: visible.origin)
        frozen.transform = transform
        frozen.opacity = 0
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
