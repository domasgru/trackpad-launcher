import AppKit
import LauncherCore
import Observation

/// Shows `updater.alert` as a free-standing, app-modal `NSAlert` with the app's icon, one at a time, and sends the
/// answer back. Its observation never runs a session: one started inside a main-queue job holds the main queue,
/// gestures included. A session starts in a run-loop callout, whose nested run loop keeps serving the main queue.
/// The alert takes no activation: it never pulls the user away from another app.
public final class UpdateAlertPresenter {
    private let updater: Updater
    /// The alert whose session runs.
    private var showing: UpdateAlert?
    private var isScheduled = false
    /// Debug only: the `-PreviewUpdates alert` alert, shown once through the same session path; its answer is dropped.
    private var previewAlert: UpdateAlert?
    private var observation: Task<Void, Never>?
    private var powerOff: NSObjectProtocol?

    public init(updater: Updater) {
        self.updater = updater
        previewAlert = UpdatesPreview.alert(running: updater.version)
        observation = Task { [weak self] in
            for await alert in Observations({ updater.alert }) { self?.changed(to: alert) }
        }
        // A two-button alert refuses a quit Apple event, so a logout, restart or shutdown would wait on it: it ends the
        // session instead.
        powerOff = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { if self?.showing != nil { NSApp.abortModal() } }
        }
        if previewAlert != nil { changed(to: previewAlert) }
    }

    isolated deinit {
        observation?.cancel()
        if let powerOff { NSWorkspace.shared.notificationCenter.removeObserver(powerOff) }
    }

    private func changed(to alert: UpdateAlert?) {
        // A model alert withdrawn: the window closed, or a hand-over.
        if let showing, showing != previewAlert, showing != alert { NSApp.abortModal() }
        guard alert != nil || previewAlert != nil, showing == nil, !isScheduled else { return }
        isScheduled = true
        RunLoop.main.perform(inModes: [.default]) {
            MainActor.assumeIsolated { self.presentWhileAny() }
        }
    }

    private func presentWhileAny() {
        isScheduled = false
        // Read now, not when scheduled.
        while let alert = previewAlert ?? updater.alert {
            showing = alert
            let response = Self.makeAlert(alert).runModal()
            showing = nil
            if alert == previewAlert {
                previewAlert = nil
                continue
            }
            updater.answer(Self.answer(for: response, in: alert), to: alert)
        }
    }

    /// `.informational`; title and message; the buttons in order, the first the default; a cancel button gets Escape.
    static func makeAlert(_ alert: UpdateAlert) -> NSAlert {
        let made = NSAlert()
        made.alertStyle = .informational
        made.messageText = alert.title
        made.informativeText = alert.message
        made.icon = NSApplication.shared.applicationIconImage
        for button in alert.buttons {
            let added = made.addButton(withTitle: button.title)
            if button.isCancel { added.keyEquivalent = "\u{1b}" }
        }
        return made
    }

    /// The pressed button's answer; an ended session (`.abort`) is dismissed.
    static func answer(for response: NSApplication.ModalResponse, in alert: UpdateAlert) -> AlertAnswer {
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        return alert.buttons.indices.contains(index) ? alert.buttons[index].answer : .dismissed
    }
}
