# Two more modes for the check copy of the spike, from the test planner's findings.
#   vetonow:      the veto runs inside the willInstallUpdateOnQuit call, as the design's order has it, both layers.
#   pendingcheck: a check refused because a cycle is ending is fired from willScheduleUpdateCheckAfterDelay.
import sys

path = f"{sys.argv[1]}/SpikeHost.swift"
text = open(path).read()

text = text.replace(
    '''        let m = mode()
        guard m != "hold" else { return true }
''',
    '''        let m = mode()
        guard m != "hold" else { return true }
        if m == "vetonow" {
            let extracted = extractedApp().map { URL(fileURLWithPath: $0).deletingLastPathComponent() }
            let removed = removeInstallerJob()
            let gone = extracted.map { (try? FileManager.default.removeItem(at: $0)) != nil } ?? false
            log("veto inside the delegate call: job removed \\(removed), folder removed \\(gone), returning true")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                log("three seconds later sessionInProgress=\\(updater.sessionInProgress), ending the process, no relauncher")
                exit(0)
            }
            return true
        }
''',
)

text = text.replace(
    '''    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        let e = error as NSError?
        log("delegate: cycle finished check=\\(updateCheck.rawValue) error=\\(e?.code ?? 0)")
    }
    func updater(_ updater: SPUUpdater, willScheduleUpdateCheckAfterDelay delay: TimeInterval) {
        log("delegate: next check in \\(Int(delay)) s")
    }
''',
    '''    var pending = false
    var refusals = 0
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        let e = error as NSError?
        log("delegate: cycle finished check=\\(updateCheck.rawValue) error=\\(e?.code ?? 0) sessionInProgress=\\(updater.sessionInProgress)")
        if mode() == "pendingcheck", refusals == 0 {
            refusals = 1
            DispatchQueue.main.async {
                log("next main turn sessionInProgress=\\(updater.sessionInProgress)")
                if updater.sessionInProgress { self.pending = true; log("a check here would be refused: remembered") }
                else { log("no refusal this time"); updater.checkForUpdatesInBackground() }
            }
        }
    }
    func updater(_ updater: SPUUpdater, willScheduleUpdateCheckAfterDelay delay: TimeInterval) {
        log("delegate: next check in \\(Int(delay)) s sessionInProgress=\\(updater.sessionInProgress)")
        if pending {
            pending = false
            log("firing the remembered check")
            updater.checkForUpdatesInBackground()
        }
    }
''',
)
open(path, "w").write(text)
print("patched")
