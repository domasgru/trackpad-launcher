import LauncherCore

/// A split gesture's bring to front as ordered steps. Pure, so a test pins the order without opening anything.
struct SplitSteps: Equatable {
    enum Step: Equatable {
        case open(AppEntry, activates: Bool, watched: Bool)
        case startWatch(BundleID)
        case bounce(AppEntry, toward: SplitSide)
        case launchAnimation(AppEntry, toward: SplitSide)
    }

    let steps: [Step]

    /// Both opens come first, the second app's before the first's, so the first app's front window ends on top and
    /// only it takes the focus when the second app is not running. Bounces start first app first, so the first app's
    /// sits on the left of the row.
    init(_ split: SplitArrival) {
        let rows = [(split.first, SplitSide.left), (split.second, SplitSide.right)]
        var steps: [Step] = []
        for (index, row) in rows.enumerated().reversed() {
            let isRunning = if case .running = row.0.entrance { true } else { false }
            steps.append(.open(row.0.app, activates: index == 0 || isRunning, watched: Self.isWatched(row.0.entrance)))
        }
        for row in rows where Self.isWatched(row.0.entrance) {
            steps.append(.startWatch(row.0.app.bundleID))
        }
        for row in rows {
            if case .launching(watch: .bouncing?) = row.0.entrance { steps.append(.bounce(row.0.app, toward: row.1)) }
        }
        for row in rows {
            if case .running(animates: true, _) = row.0.entrance {
                steps.append(.launchAnimation(row.0.app, toward: row.1))
            }
        }
        self.steps = steps
    }

    private static func isWatched(_ entrance: SplitApp.Entrance) -> Bool {
        switch entrance {
        case .running(_, followed: true), .launching(watch: .some): true
        case .running, .launching(watch: nil), .alreadyLaunching: false
        }
    }
}
