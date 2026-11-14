import AppKit
import LauncherCore
import Testing

@testable import LauncherUI

/// The real presenter over a real `Lifecycle` asking to move, with a real `runModal` session on screen. A common-mode
/// timer aborts a session still up after 5 s and fails the row, so a regression that holds the main queue fails rather
/// than hangs.
/// Every bench that runs a modal session sits under this suite: sessions of two benches must never overlap.
@Suite(.serialized) enum ModalSessions {}

extension ModalSessions {
@MainActor @Suite(.serialized) struct MoveDialogBench {
    private final class Sighting {
        var sawModal = false
        var texts: [String] = []
        var safetyFired = false
    }

    private final class Copies: RunningCopies {
        func others() -> [RunningCopy] { [] }
        func stop(_ copies: [RunningCopy], then exited: @escaping @MainActor () -> Void) { exited() }
        func endThisCopy() {}
    }

    private final class LoginItemStub: LoginItem {
        var isOn: Bool { false }
        func register() -> Bool { false }
        func unregister() {}
    }

    private final class InstallerSpy: Installer {
        var installCalls = 0
        func install(then done: @escaping @MainActor (InstallOutcome) -> Void) { installCalls += 1 }
        func removeOriginal() {}
        func openInstalledCopy() {}
        func eject(_ diskImage: DiskImage) {}
    }

    private enum Ending {
        case powerOff
        /// A quit event while the dialog shows: AppKit ends the modal with the first button's code.
        case quitEventThenFirstButton
    }

    private func run(ending: Ending) async throws -> (installer: InstallerSpy, sighting: Sighting) {
        _ = NSApplication.shared
        let name = "MoveDialogBench-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let installer = InstallerSpy()
        let lifecycle = Lifecycle(
            placement: .elsewhere, copies: Copies(), installer: installer,
            startAtLogin: StartAtLogin(item: LoginItemStub(), defaults: defaults, placement: .elsewhere),
            makeResident: { fatalError("a copy asking to move never runs gestures") },
            updater: Updater(version: AppVersion("1.1.22"), store: SettingsStore(defaults: defaults), ports: nil))
        let presenter = MoveDialogPresenter(lifecycle: lifecycle)
        let sighting = Sighting()
        let safety = Timer(timeInterval: 5, repeats: false) { _ in
            MainActor.assumeIsolated {
                sighting.safetyFired = true
                NSApp.abortModal()
            }
        }
        RunLoop.main.add(safety, forMode: .common)

        lifecycle.launched(Launch(opening: .byHand))
        DispatchQueue.global().async {
            for _ in 0..<100 {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard !sighting.sawModal, let modal = NSApp.modalWindow else { return }
                        sighting.sawModal = true
                        sighting.texts = Self.texts(in: modal.contentView)
                        switch ending {
                        case .powerOff:
                            NSWorkspace.shared.notificationCenter.post(
                                name: NSWorkspace.willPowerOffNotification, object: NSWorkspace.shared)
                        case .quitEventThenFirstButton:
                            _ = lifecycle.shouldEnd(.other)
                            NSApp.stopModal(withCode: .alertFirstButtonReturn)
                        }
                    }
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }

        let limit = ContinuousClock.now + .seconds(8)
        while ContinuousClock.now < limit, !(sighting.sawModal && NSApp.modalWindow == nil) {
            try? await Task.sleep(for: .milliseconds(20))
        }
        safety.invalidate()
        withExtendedLifetime(presenter) {}
        return (installer, sighting)
    }

    private static func texts(in view: NSView?) -> [String] {
        guard let view else { return [] }
        let own = (view as? NSTextField).map { [$0.stringValue] } ?? []
        return own + view.subviews.flatMap { texts(in: $0) }
    }

    @Test func aSessionStartedFromTheCalloutServesTheMainQueueAndAPowerOffEndsItWithNothingMoved() async throws {
        let (installer, sighting) = try await run(ending: .powerOff)

        #expect(sighting.sawModal, "a main-queue block ran while the dialog showed")
        #expect(sighting.texts.contains(Copy.moveDialogTitle))
        #expect(!sighting.safetyFired)
        #expect(NSApp.modalWindow == nil)
        #expect(installer.installCalls == 0)
    }

    @Test func aQuitEventThatEndsTheSessionAsTheFirstButtonMovesNothing() async throws {
        let (installer, sighting) = try await run(ending: .quitEventThenFirstButton)

        #expect(sighting.sawModal)
        #expect(!sighting.safetyFired)
        #expect(NSApp.modalWindow == nil)
        #expect(installer.installCalls == 0)
    }
}
}
