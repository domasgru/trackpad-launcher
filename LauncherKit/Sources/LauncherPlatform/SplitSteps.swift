import LauncherCore

/// A split gesture's bring to front as ordered steps. Pure, so a test pins the order without opening anything.
struct SplitSteps: Equatable {
    enum Step: Equatable {
        /// Without `activates`, the adapter unhides a hidden app first: only activation unhides.
        case open(AppEntry, activates: Bool, watched: Bool)
        /// A running app brought to front without the focus and without the reopen an open sends, which some apps
        /// (Electron ones) answer by activating themselves: unhidden, and opened without activation only when it has
        /// no window to show, such as all minimised.
        case reveal(AppEntry, watched: Bool)
        /// For a moment, the app gets the focus back when `other` takes it by itself.
        case keepFocus(AppEntry, against: BundleID)
        case startWatch(BundleID)
        case bounce(AppEntry, toward: SplitSide)
        case launchAnimation(AppEntry, toward: SplitSide)
    }

    let steps: [Step]

    /// Both apps come to front first, the focused one last, so it ends active with its front window on top. The other
    /// app never takes the focus while launching. When it runs, it is activated just before the focused app when
    /// `secondEntry` is `.focused`, and only revealed when `.unfocused`. Then the focused app is kept active against
    /// the other. Bounces start first app first, so the first app's sits on the left of the row.
    init(_ split: SplitArrival) {
        let sides = [(member: split.first, side: SplitSide.left), (member: split.second, side: SplitSide.right)]
        let focused = split.focused, other = split.other
        let isOtherRunning = if case .running = other.entrance { true } else { false }
        let otherWatched = Self.isWatched(other.entrance)
        var steps: [Step] = []
        switch (split.secondEntry, isOtherRunning) {
        case (.focused, true): steps.append(.open(other.app, activates: true, watched: otherWatched))
        case (.unfocused, true): steps.append(.reveal(other.app, watched: otherWatched))
        case (_, false): steps.append(.open(other.app, activates: false, watched: otherWatched))
        }
        steps.append(.open(focused.app, activates: true, watched: Self.isWatched(focused.entrance)))
        steps.append(.keepFocus(focused.app, against: other.app.bundleID))
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
