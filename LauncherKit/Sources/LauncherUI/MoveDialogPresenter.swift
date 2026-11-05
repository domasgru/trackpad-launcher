import AppKit
import LauncherCore
import Observation

/// Renders `lifecycle.moveDialog` as an alert run modally, activating the app once it shows (an accessory app
/// activates without a Dock icon), and sends the answer back.
public final class MoveDialogPresenter {
    private var observation: Task<Void, Never>?

    public init(lifecycle: Lifecycle) {
        observation = Task { [weak self] in
            for await dialog in Observations({ lifecycle.moveDialog }) {
                guard let dialog else { continue }
                self?.run(dialog, answering: lifecycle)
            }
        }
    }

    isolated deinit {
        observation?.cancel()
    }

    private func run(_ dialog: MoveDialog, answering lifecycle: Lifecycle) {
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
        let isFirstButton = alert.runModal() == .alertFirstButtonReturn
        switch dialog {
        case .asking: lifecycle.answer(isFirstButton ? .move : .quit)
        case .failed: lifecycle.answer(.quit)
        }
    }
}
