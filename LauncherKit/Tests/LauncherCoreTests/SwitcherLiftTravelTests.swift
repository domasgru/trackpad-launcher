import Testing
import LauncherCore

@MainActor @Suite struct SwitcherLiftTravelTests {
    private let apps = ["Safari", "Mail", "Slack", "Notes", "Preview", "Music"]

    private func hand(_ world: World) -> TouchScript {
        TouchScript(.macBook14).thumb(atMM: (10, 10)).land(fingers: 2).slide(byMM: (3.5, 0)).slide(byMM: (48, 0))
    }

    @Test func aLiftOnTheFrameAfterTheLastMovementOpensWhatTheHighlightShowsNotWhereTheFingersReached() {
        let world = World.switcherWorld(apps: apps)
        let script = hand(world)
        var selected: [String] = []
        for step in world.playFrameByFrame(script, observing: { world.launcher.switcher?.selectedApp.name }) {
            if let step { selected.append(step) }
        }
        #expect(selected.last == "Notes")

        for step in world.playFrameByFrame(script.lift(), observing: { world.launcher.switcher?.selectedApp.name }) {
            if let step { selected.append(step) }
        }
        #expect(world.system.broughtToFront == [world.app("Notes")])
        #expect(world.hardware.feedback.count == 1)
        #expect(!selected.contains("Preview"))
    }

    @Test func theSameHandSettlingBeforeTheLiftOpensWhereTheFingersReached() {
        let world = World.switcherWorld(apps: apps)
        world.play(hand(world).settle().lift())
        #expect(world.system.broughtToFront == [world.app("Preview")])
    }
}
