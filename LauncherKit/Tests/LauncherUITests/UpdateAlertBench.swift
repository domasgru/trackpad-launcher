import AppKit
import LauncherCore
import Testing

@testable import LauncherUI

/// The real presenter over a portless `Updater`, with real `runModal` sessions on screen. A common-mode timer aborts a
/// session still up after 5 s and fails the row, so a regression that holds the main queue fails rather than hangs.
@MainActor @Suite(.serialized) struct UpdateAlertBench {
    private final class Sighting {
        var sawModal = false
        var sheetParent: NSWindow?
        var texts: [String] = []
        var safetyFired = false
    }

    private enum Ending { case answered, powerOff }

    /// Opens `.unavailable`, waits on a background thread's main-queue blocks until the session shows, then ends it
    /// the way `ending` says.
    private func run(ending: Ending) async throws -> (updater: Updater, sighting: Sighting) {
        _ = NSApplication.shared
        let name = "UpdateAlertBench-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let updater = Updater(version: AppVersion("1.1.22"), store: SettingsStore(defaults: defaults), ports: nil)
        let presenter = UpdateAlertPresenter(updater: updater)
        let sighting = Sighting()
        let safety = Timer(timeInterval: 5, repeats: false) { _ in
            MainActor.assumeIsolated {
                sighting.safetyFired = true
                NSApp.abortModal()
            }
        }
        RunLoop.main.add(safety, forMode: .common)

        updater.checkForUpdates()
        DispatchQueue.global().async {
            for _ in 0..<100 {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard !sighting.sawModal, let modal = NSApp.modalWindow else { return }
                        sighting.sawModal = true
                        sighting.sheetParent = modal.sheetParent
                        sighting.texts = Self.texts(in: modal.contentView)
                        switch ending {
                        case .answered: updater.answer(.dismissed, to: .unavailable)
                        case .powerOff:
                            NSWorkspace.shared.notificationCenter.post(
                                name: NSWorkspace.willPowerOffNotification, object: NSWorkspace.shared)
                        }
                    }
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }

        let limit = ContinuousClock.now + .seconds(8)
        while ContinuousClock.now < limit, !(sighting.sawModal && updater.alert == nil && NSApp.modalWindow == nil) {
            try? await Task.sleep(for: .milliseconds(20))
        }
        safety.invalidate()
        withExtendedLifetime(presenter) {}
        return (updater, sighting)
    }

    private static func texts(in view: NSView?) -> [String] {
        guard let view else { return [] }
        let own = (view as? NSTextField).map { [$0.stringValue] } ?? []
        return own + view.subviews.flatMap { texts(in: $0) }
    }

    @Test func aSessionStartedFromTheCalloutServesTheMainQueueIsFreeStandingAndEndsWhenAnswered() async throws {
        let (updater, sighting) = try await run(ending: .answered)

        #expect(sighting.sawModal, "a main-queue block ran while the alert showed")
        #expect(sighting.sheetParent == nil)
        #expect(sighting.texts.contains("Updates aren't available for this copy"))
        #expect(!sighting.safetyFired)
        #expect(updater.alert == nil)
        #expect(NSApp.modalWindow == nil)
    }

    @Test func aPowerOffEndsTheSessionUnansweredAndTheModelWithdrawsTheAlert() async throws {
        let (updater, sighting) = try await run(ending: .powerOff)

        #expect(sighting.sawModal)
        #expect(!sighting.safetyFired)
        #expect(updater.alert == nil)
        #expect(NSApp.modalWindow == nil)
    }
}
