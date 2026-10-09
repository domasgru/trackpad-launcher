import Foundation
import Testing
import LauncherCore

@MainActor @Suite struct AppResolutionTests {
    @Test func pickedInstalledAppShowsOnItsRow() {
        let world = World(apps: ["Figma"])
        world.launcher.start()

        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)

        #expect(world.launcher.app(for: .two) == .present(world.app("Figma")))
    }

    @Test func otherAcceptsAnAppBundleAndIgnoresAnythingElse() throws {
        let world = World()
        world.launcher.start()
        let sketch = world.install("Sketch", in: world.downloads)
        let notes = world.downloads.appending(path: "Notes.txt")
        try Data().write(to: notes)

        world.launcher.setAssignment(.appBundle(at: sketch), for: .one)
        let entry = world.app("Sketch", in: world.downloads)
        #expect(world.launcher.app(for: .one) == .present(entry))

        world.launcher.setAssignment(.appBundle(at: notes), for: .one)
        #expect(world.launcher.app(for: .one) == .present(entry))

        world.tap(1)
        #expect(world.system.broughtToFront == [entry])
    }

    @Test func unassigningClearsTheRowForeverAndSilencesTheGesture() {
        let world = World(apps: ["Notion"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Notion")), for: .three)

        world.launcher.setAssignment(.unassigned, for: .three)
        #expect(world.launcher.app(for: .three) == .unassigned)

        let relaunched = world.relaunch()
        relaunched.start()
        #expect(relaunched.app(for: .three) == .unassigned)
        world.tap(3)
        #expect(world.system.broughtToFront.isEmpty)
    }

    @Test func theSameAppCanSitOnTwoGestures() {
        let world = World(apps: ["Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Arc")), for: .one)

        world.launcher.setAssignment(.app(world.app("Arc")), for: .four)

        #expect(world.launcher.app(for: .one) == .present(world.app("Arc")))
        #expect(world.launcher.app(for: .four) == .present(world.app("Arc")))
    }

    @Test func trashedAppIsMissingSilentAndStillReplaceable() {
        let world = World(apps: ["Figma", "Arc"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
        world.registry[World.bundleID("Figma")] = [world.trash("Figma")]

        world.launcher.openWindow()
        #expect(world.launcher.app(for: .two) == .missing(name: "Figma"))
        world.tap(2)
        #expect(world.system.broughtToFront.isEmpty)
        #expect(world.hardware.feedback.isEmpty)

        world.launcher.setAssignment(.app(world.app("Arc")), for: .two)
        #expect(world.launcher.app(for: .two) == .present(world.app("Arc")))
    }

    @Test func movedAppKeepsWorkingAndTheStoredLocationIsNeverRewritten() {
        let world = World(apps: ["Figma"])
        world.launcher.start()
        let original = world.app("Figma").url
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
        let moved = world.move("Figma", to: world.userApplications)
        world.registry[World.bundleID("Figma")] = [moved]
        let entry = world.app("Figma", in: world.userApplications)

        world.tap(2)
        #expect(world.system.broughtToFront == [entry])
        world.launcher.openWindow()
        #expect(world.launcher.app(for: .two) == .present(entry))

        #expect(world.store.load()?.assignments[.two]?.lastKnownURL == original)
    }

    @Test func reinstalledAppRecoversWithoutRepicking() {
        let world = World(apps: ["Figma"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
        world.registry[World.bundleID("Figma")] = [world.trash("Figma")]
        world.launcher.openWindow()
        #expect(world.launcher.app(for: .two) == .missing(name: "Figma"))

        let reinstalled = world.install("Figma")
        world.registry[World.bundleID("Figma")] = [reinstalled]
        world.launcher.openWindow()
        #expect(world.launcher.app(for: .two) == .present(world.app("Figma")))

        world.tap(2)
        #expect(world.system.broughtToFront == [world.app("Figma")])
    }

    @Test func aDifferentBundleAtTheOldLocationIsNotTheAssignedApp() {
        let world = World(apps: ["Figma"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
        world.remove("Figma")
        world.install("Figma", bundleID: "com.other.figma")
        world.registry[World.bundleID("Figma")] = []

        world.launcher.openWindow()

        #expect(world.launcher.app(for: .two) == .missing(name: "Figma"))
    }

    @Test func trashedCopiesNeverCountWhenARealCopyExists() {
        let world = World(apps: ["Figma"])
        world.launcher.start()
        world.launcher.setAssignment(.app(world.app("Figma")), for: .two)
        let trashed = world.trash("Figma")
        let live = world.install("Figma", in: world.userApplications)
        world.registry[World.bundleID("Figma")] = [trashed, live]

        world.tap(2)

        #expect(world.system.broughtToFront == [world.app("Figma", in: world.userApplications)])
    }
}
