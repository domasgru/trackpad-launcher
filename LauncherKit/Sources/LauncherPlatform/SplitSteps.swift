import LauncherCore

/// A split gesture's bring to front as ordered steps. Pure, so a test pins the order without opening anything.
struct SplitSteps: Equatable {
    enum Step: Equatable {
        /// Without `activates`, the adapter unhides a hidden app first: only activation unhides.
        case open(AppEntry, activates: Bool, watched: Bool)
        case startWatch(BundleID)
        case bounce(AppEntry, toward: SplitSide)
        case launchAnimation(AppEntry, toward: SplitSide)
    }

    let steps: [Step]

    /// Both opens come first, the second app's before the first's, so the first app's front window ends on top and
    /// the first app ends active. A launching second app never takes the focus, and its windows open in front of every
    /// app's but the active one. A running one takes it for a moment when `secondEntry` is `.focused`; when it is
    /// `.unfocused`, it opens without it, unhidden, restored or reopened as a Dock click would. Bounces start first app
    /// first, so the first app's sits on the left of the row.
    init(_ split: SplitArrival) {
        let sides = [(member: split.first, side: SplitSide.left), (member: split.second, side: SplitSide.right)]
        let isSecondRunning = if case .running = split.second.entrance { true } else { false }
        var steps: [Step] = []
        steps.append(
            .open(
                split.second.app, activates: isSecondRunning && split.secondEntry == .focused,
                watched: Self.isWatched(split.second.entrance)))
        steps.append(.open(split.first.app, activates: true, watched: Self.isWatched(split.first.entrance)))
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
