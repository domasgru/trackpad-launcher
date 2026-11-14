import AppKit
import LauncherCore
import Observation

/// Renders `lifecycle.moveDialog` as an alert run modally, activating the app once it shows (an accessory app
/// activates without a Dock icon), and sends the answer back. Its observation never runs the session: one started
/// inside a main-queue job holds the main queue, gestures included. The session starts in a run-loop callout, whose
/// nested run loop keeps serving the main queue. A power-off ends it unanswered, so the dialog holds up no logout.
public final class MoveDialogPresenter {
    private let lifecycle: Lifecycle
    private var isShowing = false
    private var isScheduled = false
    private var observation: Task<Void, Never>?
    private var powerOff: NSObjectProtocol?

    public init(lifecycle: Lifecycle) {
        self.lifecycle = lifecycle
        observation = Task { [weak self] in
            for await dialog in Observations({ lifecycle.moveDialog }) {
                if dialog != nil { self?.schedule() }
            }
        }
        powerOff = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.lifecycle.powerOffAnnounced()
                if self.isShowing { NSApp.abortModal() }
            }
        }
    }

    isolated deinit {
        observation?.cancel()
        if let powerOff { NSWorkspace.shared.notificationCenter.removeObserver(powerOff) }
    }

    private func schedule() {
        guard !isShowing, !isScheduled else { return }
        isScheduled = true
        RunLoop.main.perform(inModes: [.default]) {
            MainActor.assumeIsolated {
                self.isScheduled = false
                // Read now, not when scheduled.
                guard !self.isShowing, let dialog = self.lifecycle.moveDialog else { return }
                self.run(dialog)
            }
        }
    }

    private func run(_ dialog: MoveDialog) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        switch dialog {
        case .asking:
            alert.messageText = Copy.moveDialogTitle
            alert.informativeText = Copy.moveDialogMessage
            alert.addButton(withTitle: Copy.moveButton)
            alert.addButton(withTitle: Copy.moveQuitButton)
        case .failed(let reason):
            alert.messageText = Copy.moveFailedTitle
            alert.informativeText = reason
            alert.addButton(withTitle: Copy.moveQuitButton)
        }
        // The system drops an activation while the app has no window on screen, so it runs inside the modal session,
        // once the alert shows. Ordering the alert front here instead would stop AppKit centring it.
        RunLoop.main.perform(inModes: [.modalPanel]) {
            MainActor.assumeIsolated { AppActivation.activateOverOtherApps() }
        }
        isShowing = true
        let isFirstButton = alert.runModal() == .alertFirstButtonReturn
        isShowing = false
        switch dialog {
        case .asking: lifecycle.answer(isFirstButton ? .move : .quit)
        case .failed: lifecycle.answer(.quit)
        }
        // The answer may have led straight to another dialog, which the observation saw while this session ran.
        schedule()
    }
}
