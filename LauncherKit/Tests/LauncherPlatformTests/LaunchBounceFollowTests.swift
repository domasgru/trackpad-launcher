import AppKit
import ApplicationServices
import LauncherCore
import Testing

@testable import LauncherPlatform

/// The row follows the pointer, driven by zero-motion moves posted at the pointer's own location while the injected
/// read says where the tip is. Posting needs Accessibility, so the rows are skipped without it. They extend the
/// adapter suite so that they run one at a time with its rows.
extension LaunchBounceAdapterTests {
    nonisolated private static var canPost: Bool { AXIsProcessTrusted() }

    private func postMove() {
        let here = CGEvent(source: nil)?.location ?? .zero
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: here, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    /// Runs the application loop for `duration`: the test process has none, and the monitors only hear events the
    /// application pulls. Core Animation commits on its turns too.
    private func runApplication(for duration: Duration) {
        let app = NSApplication.shared
        let timer = Timer(timeInterval: duration.seconds, repeats: false) { _ in
            MainActor.assumeIsolated {
                app.stop(nil)
                if let wake = NSEvent.otherEvent(
                    with: .applicationDefined, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                    context: nil, subtype: 0, data1: 0, data2: 0)
                {
                    app.postEvent(wake, atStart: true)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        app.run()
    }

    /// Ends the bounce quietly and reads the fade window shortly after, while it is still fading.
    private func fade(ofFirst first: ProbeBundles.Bundle, in bench: BounceBench, width: CGFloat) -> CGRect? {
        bench.actions.endLaunchBounce(of: BundleID(rawValue: first.id), with: .quietFade)
        runApplication(for: .milliseconds(60))
        return OwnWindows.panels().first { $0.width < width }
    }

    @Test(.enabled(if: canPost))
    func theRowStaysGluedToThePointerAndAnEndedIconNoLongerFollows() async {
        await ProbeBundles.withProbes { probes in
            let bench = BounceBench()
            let probe = probes.make(["preSleep": 5])
            defer { bench.tearDown([probe]) }
            LaunchTuning.setReduceMotion(true)
            defer { LaunchTuning.setReduceMotion(false) }
            let screen = BounceBench.display(holding: CGPoint(x: 500, y: 400))

            bench.tip = CGPoint(x: 500, y: 400)
            bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .seconds(10))
            runApplication(for: .milliseconds(100))
            bench.tip = CGPoint(x: 900, y: 500)
            postMove()
            runApplication(for: .milliseconds(100))

            let ended = fade(ofFirst: probe, in: bench, width: screen.width)
            #expect(
                ended.map { abs($0.midX - 900) < 1 && abs($0.minY - 508) < 1 } == true,
                "glued at (900, 508): \(String(describing: ended))")

            bench.tip = CGPoint(x: 300, y: 300)
            postMove()
            runApplication(for: .milliseconds(40))
            let later = OwnWindows.panels().first { $0.width < screen.width }
            #expect(later == ended, "the ended icon stays: \(String(describing: later))")
        }
    }

    @Test(.enabled(if: canPost))
    func theRowFollowsThePointerOntoAnotherDisplay() async {
        await ProbeBundles.withProbes { probes in
            let bench = BounceBench()
            let probe = probes.make(["preSleep": 5])
            defer { bench.tearDown([probe]) }
            LaunchTuning.setReduceMotion(true)
            defer { LaunchTuning.setReduceMotion(false) }
            let screen = BounceBench.display(holding: CGPoint(x: 500, y: 400))
            let left = LaunchDisplay(frame: CGRect(x: 0, y: 0, width: 800, height: 600), scale: 1)
            let right = LaunchDisplay(frame: CGRect(x: 800, y: 0, width: 600, height: 600), scale: 2)
            bench.setDisplays([left, right])

            bench.tip = CGPoint(x: 500, y: 400)
            bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .seconds(10))
            runApplication(for: .milliseconds(100))
            #expect(OwnWindows.panels().contains(left.frame), "the row starts on the left display: \(OwnWindows.panels())")

            bench.tip = CGPoint(x: 1100, y: 300)
            postMove()
            runApplication(for: .milliseconds(100))
            #expect(OwnWindows.panels().contains(right.frame), "re-framed to the right display: \(OwnWindows.panels())")

            let ended = fade(ofFirst: probe, in: bench, width: screen.width)
            #expect(
                ended.map { abs($0.midX - 1100) < 1 && abs($0.minY - 308) < 1 } == true,
                "rests there: \(String(describing: ended))")
        }
    }

    @Test(.enabled(if: canPost))
    func trailingMakesTheRowLagBehindThePointer() async {
        await ProbeBundles.withProbes { probes in
            let bench = BounceBench()
            let probe = probes.make(["preSleep": 5])
            defer { bench.tearDown([probe]) }
            LaunchTuning.setTrailing(0.5)
            defer { LaunchTuning.setReduceMotion(false) }
            let screen = BounceBench.display(holding: CGPoint(x: 500, y: 400))

            bench.tip = CGPoint(x: 500, y: 400)
            bench.actions.bringToFrontBouncing(bench.entry(probe), cap: .seconds(10))
            runApplication(for: .milliseconds(100))
            bench.tip = CGPoint(x: 900, y: 400)
            postMove()
            runApplication(for: .milliseconds(50))

            let ended = fade(ofFirst: probe, in: bench, width: screen.width)
            #expect(ended.map { $0.midX > 505 && $0.midX < 895 } == true, "between the two rests: \(String(describing: ended))")
        }
    }
}

extension LaunchTuning {
    /// Forces the Reduce motion look and sets the row's trailing; `setReduceMotion(false)` restores the shipped tuning.
    @MainActor static func setTrailing(_ seconds: Double) {
        #if DEBUG
        var tuning = LaunchTuning.shipped
        tuning.forceReduceMotion = true
        tuning.bounce.trailing = seconds
        tunerOverride.withLock { $0 = tuning }
        #endif
    }
}
