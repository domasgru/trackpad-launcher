import AppKit
import LauncherCore
import Testing

@testable import LauncherUI

private enum Alerts {
    nonisolated static let running = AppVersion("1.1.22")
    nonisolated static let offered = UpdateAlert.updateAvailable(from: running, to: AppVersion("1.1.23"))
    nonisolated static let all: [UpdateAlert] = [
        offered, .upToDate(running), .checkFailed, .installFailed(running: running), .unavailable,
    ]
}

@MainActor @Suite struct UpdateAlertTests {
    @Test(arguments: Alerts.all)
    func anAlertIsInformationalWithItsTitleMessageAndButtonsInOrder(alert: UpdateAlert) {
        _ = NSApplication.shared
        let made = UpdateAlertPresenter.makeAlert(alert)

        #expect(made.alertStyle == .informational)
        #expect(made.messageText == alert.title)
        #expect(made.informativeText == alert.message)
        #expect(made.buttons.map { $0.title } == alert.buttons.map { $0.title })
        #expect(made.buttons.first?.keyEquivalent == "\r")
        for (button, spec) in zip(made.buttons, alert.buttons) where spec.isCancel {
            #expect(button.keyEquivalent == "\u{1b}")
        }
    }

    @Test func theUpdateAlertsNotNowTakesEscapeAndItsUpdateIsTheDefault() {
        _ = NSApplication.shared
        let made = UpdateAlertPresenter.makeAlert(Alerts.offered)

        #expect(made.buttons.map { $0.title } == ["Update", "Not now"])
        #expect(made.buttons.map { $0.keyEquivalent } == ["\r", "\u{1b}"])
    }

    @Test func aPressedButtonAnswersAsItsSpecSaysAndAnEndedSessionIsDismissed() {
        #expect(UpdateAlertPresenter.answer(for: .alertFirstButtonReturn, in: Alerts.offered) == .update)
        #expect(UpdateAlertPresenter.answer(for: .alertSecondButtonReturn, in: Alerts.offered) == .dismissed)
        #expect(UpdateAlertPresenter.answer(for: .abort, in: Alerts.offered) == .dismissed)
        #expect(UpdateAlertPresenter.answer(for: .alertFirstButtonReturn, in: .checkFailed) == .dismissed)
    }
}
