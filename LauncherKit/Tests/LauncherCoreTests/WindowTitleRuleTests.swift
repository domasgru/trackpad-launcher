import Testing
import LauncherCore

private let vsCode = AppEntry(
    bundleID: BundleID(rawValue: "com.microsoft.VSCode"), name: "Code",
    url: AppEntry.location(ofBundleAtPath: "/Applications/Visual Studio Code.app"))
private let vsCodeInsiders = AppEntry(
    bundleID: BundleID(rawValue: "com.microsoft.VSCodeInsiders"), name: "Code - Insiders",
    url: AppEntry.location(ofBundleAtPath: "/Applications/Visual Studio Code - Insiders.app"))

@MainActor @Suite struct WindowTitleRuleTests {
    private func vsCodeWorld(
        visible: [String], minimised: [String] = [], untitled: Set<String> = []
    ) -> World {
        let world = World.windowWorld(visible: visible, minimised: minimised, untitled: untitled)
        world.system.frontmost = vsCode
        return world
    }

    private func titles(_ world: World) -> [String]? { world.launcher.windowSwitcher?.rows.map(\.title) }

    @Test(arguments: [
        (frontmost: vsCode as AppEntry?,
         raw: ["product-overview.md — trackpad-launcher", "how-explorer.md — skills"],
         shown: ["trackpad-launcher — product-overview.md", "skills — how-explorer.md"]),
        (frontmost: vsCodeInsiders as AppEntry?,
         raw: ["main.swift — trackpad-launcher", "how-explorer.md — skills"],
         shown: ["trackpad-launcher — main.swift", "skills — how-explorer.md"]),
        (frontmost: nil as AppEntry?, // no active app
         raw: ["Apple — Start Page", "how-explorer.md — skills"],
         shown: ["Apple — Start Page", "how-explorer.md — skills"]),
    ])
    func eachAppsRowsReadAsItsTitleRuleWordsThem(frontmost: AppEntry?, raw: [String], shown: [String]) {
        let world = World.windowWorld(visible: raw)
        if let frontmost { world.system.frontmost = frontmost }

        world.windowSwipe(3.5, lift: false)

        let switcher = world.launcher.windowSwitcher
        #expect(titles(world) == shown)
        #expect(switcher?.selection.selected == 0)
        #expect(switcher?.rows.map(\.window) == raw.map { world.window($0) })
    }

    @Test func minimisedRowsAreReworded() {
        let world = vsCodeWorld(visible: ["README.md"], minimised: ["main.swift — trackpad-launcher"])

        world.windowSwipe(3.5, lift: false)

        #expect(
            world.launcher.windowSwitcher?.rows == [
                .visible(world.window("README.md"), title: "README.md"),
                .minimised(world.window("main.swift — trackpad-launcher"), title: "trackpad-launcher — main.swift"),
            ])
    }

    @Test func liftingOnARewordedRowRaisesTheWindowItCameFrom() {
        let world = vsCodeWorld(visible: ["main.swift — trackpad-launcher", "README.md — skills"])

        let hand = world.windowSwipe(3.5, 12, lift: false)
        #expect(titles(world) == ["trackpad-launcher — main.swift", "skills — README.md"])
        #expect(world.launcher.windowSwitcher?.selection.selected == 1)

        world.play(hand.lift())
        #expect(world.system.windows.onScreenTitles == ["README.md — skills", "main.swift — trackpad-launcher"])
        #expect(world.hardware.pulses.map(\.haptic).filter { $0 == .gesture }.count == 1)
    }

    @Test(arguments: [
        (raw: "main.swift — trackpad-launcher — Work", shown: "trackpad-launcher — main.swift — Work"),
        (raw: "main.swift — myspace (Workspace)", shown: "myspace (Workspace) — main.swift"),
        (raw: "main.swift — trackpad-launcher [SSH: host]", shown: "trackpad-launcher [SSH: host] — main.swift"),
        (raw: "● main.swift — trackpad-launcher", shown: "trackpad-launcher — ● main.swift"),
    ])
    func laterPartsKeepTheirOrderAndEveryPartKeepsItsText(raw: String, shown: String) {
        let world = vsCodeWorld(visible: [raw, "how-explorer.md — skills"])

        world.windowSwipe(3.5, lift: false)

        #expect(titles(world) == [shown, "skills — how-explorer.md"])
    }

    @Test(arguments: ["trackpad-launcher", "notes.md"])
    func aTitleWithoutTheSeparatorIsShownAsVSCodeGivesIt(raw: String) {
        let world = vsCodeWorld(visible: [raw, "how-explorer.md — skills"])

        world.windowSwipe(3.5, lift: false)

        #expect(titles(world) == [raw, "skills — how-explorer.md"])
    }

    @Test func anUntitledVSCodeWindowKeepsTheAppNamedFallback() {
        let world = vsCodeWorld(visible: ["main.swift — trackpad-launcher", "U1"], untitled: ["U1"])

        world.windowSwipe(3.5, lift: false)

        #expect(titles(world) == ["trackpad-launcher — main.swift", "Code — Window 2"])
    }
}
