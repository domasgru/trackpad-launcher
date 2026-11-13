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
        let sides = [(member: split.first, side: SplitSide.left), (member: split.second, side: SplitSide.right)]
        var steps: [Step] = []
        for (index, entry) in sides.enumerated().reversed() {
            let isRunning = if case .running = entry.member.entrance { true } else { false }
            let watched = Self.isWatched(entry.member.entrance)
            steps.append(.open(entry.member.app, activates: index == 0 || isRunning, watched: watched))
        }
        for entry in sides where Self.isWatched(entry.member.entrance) {
            steps.append(.startWatch(entry.member.app.bundleID))
        }
        for entry in sides {
            if case .launching(watch: .bouncing?) = entry.member.entrance {
                steps.append(.bounce(entry.member.app, toward: entry.side))
            }
        }
        for entry in sides {
            if case .running(animates: true, _) = entry.member.entrance {
                steps.append(.launchAnimation(entry.member.app, toward: entry.side))
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
