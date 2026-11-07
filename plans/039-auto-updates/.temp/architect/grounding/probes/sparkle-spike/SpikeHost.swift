// Probe host for Sparkle 2.10.1. An LSUIElement app that updates itself through
// the automatic path, with a user driver that shows nothing. Everything it sees
// goes to one log file with a wall clock stamp, so each scenario's timeline can be read back.
//
// The mode is read from /tmp/039-sparkle/spike/run/mode at start:
//   selfquit   hold the install, then submit a one-shot launchd relauncher and end this process
//   plainquit  hold the install, then end this process with no relauncher (R13: quit stays final)
//   immediate  hold the install, then call Sparkle's immediate install handler
//   veto       hold the install, then remove Sparkle's installer job, then check again
//   hold       hold the install forever
//   failquit   like selfquit, but first make the bundle's parent unwritable so the swap fails
import AppKit
import ServiceManagement
import Sparkle

let runDir = "/tmp/039-sparkle/spike/run"

func stamp() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f.string(from: Date())
}

func log(_ line: String) {
    let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    let text = "\(stamp()) v\(version) pid=\(getpid()) \(line)\n"
    let url = URL(fileURLWithPath: "\(runDir)/host.log")
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(text.data(using: .utf8)!)
        try? handle.close()
    } else {
        try? text.data(using: .utf8)!.write(to: url)
    }
}

func mode() -> String {
    (try? String(contentsOfFile: "\(runDir)/mode", encoding: .utf8))?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "hold"
}

func frontmost() -> String {
    NSWorkspace.shared.frontmostApplication?.localizedName ?? "none"
}

/// Shows nothing and never agrees to anything. On the automatic path Sparkle does not
/// consult it; if any of these lines appear in a run, that run left the automatic path.
final class SilentDriver: NSObject, SPUUserDriver {
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        log("driver: permission request")
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, automaticUpdateDownloading: true, sendSystemProfile: false))
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) { log("driver: user initiated") }
    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        log("driver: update found stage=\(state.stage.rawValue) -> dismiss")
        reply(.dismiss)
    }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        log("driver: not found"); acknowledgement()
    }
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        log("driver: error \(error)"); acknowledgement()
    }
    func showDownloadInitiated(cancellation: @escaping () -> Void) { log("driver: download initiated") }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
    func showDownloadDidReceiveData(ofLength length: UInt64) {}
    func showDownloadDidStartExtractingUpdate() { log("driver: extracting") }
    func showExtractionReceivedProgress(_ progress: Double) {}
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        log("driver: ready to install -> dismiss"); reply(.dismiss)
    }
    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        log("driver: installing terminated=\(applicationTerminated)")
    }
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        log("driver: installed relaunched=\(relaunched)"); acknowledgement()
    }
    func dismissUpdateInstallation() { log("driver: dismiss") }
}

final class Delegate: NSObject, SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        log("delegate: found \(item.versionString) url=\(item.fileURL?.absoluteString ?? "nil")")
    }
    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        let e = error as NSError
        log("delegate: not found code=\(e.code) reason=\(e.userInfo[SPUNoUpdateFoundReasonKey] ?? "nil")")
    }
    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) { log("delegate: downloaded") }
    func updater(_ updater: SPUUpdater, willExtractUpdate item: SUAppcastItem) { log("delegate: will extract") }
    func updater(_ updater: SPUUpdater, didExtractUpdate item: SUAppcastItem) { log("delegate: did extract") }
    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) { log("delegate: will install") }
    func updaterWillRelaunchApplication(_ updater: SPUUpdater) { log("delegate: will relaunch") }
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let e = error as NSError
        let under = e.userInfo[NSUnderlyingErrorKey] as? NSError
        log("delegate: aborted domain=\(e.domain) code=\(e.code) under=\(under?.domain ?? "-")/\(under?.code ?? 0) \(e.localizedDescription)")
    }
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        let e = error as NSError?
        log("delegate: cycle finished check=\(updateCheck.rawValue) error=\(e?.code ?? 0)")
    }
    func updater(_ updater: SPUUpdater, willScheduleUpdateCheckAfterDelay delay: TimeInterval) {
        log("delegate: next check in \(Int(delay)) s")
    }

    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        let extracted = extractedApp()
        log("delegate: WILL INSTALL ON QUIT \(item.versionString) sessionInProgress=\(updater.sessionInProgress) extracted=\(extracted ?? "nil") front=\(frontmost())")
        let m = mode()
        guard m != "hold" else { return true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            switch m {
            case "selfquit":
                submitRelauncher()
                log("ending this process front=\(frontmost())")
                exit(0)
            case "windowquit":
                // The state R8's install happens in after the user once used the settings window:
                // a regular app with a window, then an accessory with that window closed.
                NSApp.setActivationPolicy(.regular)
                let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 200, height: 120), styleMask: [.titled, .closable], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                log("window shown active=\(NSApp.isActive) policy=\(NSApp.activationPolicy().rawValue)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    window.orderOut(nil)
                    NSApp.setActivationPolicy(.accessory)
                    log("window closed active=\(NSApp.isActive) policy=\(NSApp.activationPolicy().rawValue)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        submitRelauncher()
                        log("ending this process front=\(frontmost())")
                        exit(0)
                    }
                }
            case "failquit":
                let parent = Bundle.main.bundleURL.deletingLastPathComponent().path
                let done = (try? FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: parent)) != nil
                log("made \(parent) read-only: \(done)")
                submitRelauncher()
                log("ending this process")
                exit(0)
            case "plainquit":
                log("ending this process, no relauncher")
                exit(0)
            case "immediate":
                log("calling the immediate install handler front=\(frontmost())")
                immediateInstallHandler()
            case "veto":
                let removed = removeInstallerJob()
                log("removed the installer job: \(removed)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    log("after veto sessionInProgress=\(updater.sessionInProgress)")
                    if updater.sessionInProgress == false {
                        log("checking again")
                        updater.checkForUpdatesInBackground()
                    }
                }
            default:
                break
            }
        }
        return true
    }
}

/// The app Sparkle extracted, found by the same path a host would have to know.
func extractedApp() -> String? {
    let id = Bundle.main.bundleIdentifier!
    let root = "\(NSHomeDirectory())/Library/Caches/\(id)/org.sparkle-project.Sparkle/Installation"
    guard let walk = FileManager.default.enumerator(atPath: root) else { return nil }
    for case let path as String in walk where path.hasSuffix(".app") {
        return "\(root)/\(path)"
    }
    return nil
}

func removeInstallerJob() -> Bool {
    let label = "\(Bundle.main.bundleIdentifier!)-sparkle-updater" as CFString
    var auth: AuthorizationRef?
    guard AuthorizationCreate(nil, nil, [], &auth) == errSecSuccess, let auth else { return false }
    defer { AuthorizationFree(auth, []) }
    var error: Unmanaged<CFError>?
    let done = SMJobRemove(kSMDomainUserLaunchd, label, auth, true, &error)
    if let e = error?.takeRetainedValue() { log("SMJobRemove error \(e)") }
    return done
}

/// A one-shot launchd job: it outlives this process and is nobody's child.
func submitRelauncher() {
    let oldVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    let path = Bundle.main.bundlePath
    let script = """
    me=$1; bundle=$2; old=$3; log=\(runDir)/relauncher.log
    echo "$(date +%H:%M:%S) relauncher started, waiting for pid $me" >> "$log"
    while kill -0 "$me" 2>/dev/null; do sleep 0.05; done
    echo "$(date +%H:%M:%S) old process gone" >> "$log"
    i=0
    while [ $i -lt 100 ]; do
      now=$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$bundle/Contents/Info.plist" 2>/dev/null)
      [ "$now" != "$old" ] && break
      sleep 0.05; i=$((i+1))
    done
    echo "$(date +%H:%M:%S) version now $now after $i waits" >> "$log"
    /usr/bin/open -g -a "$bundle" --args --after-update
    echo "$(date +%H:%M:%S) open returned $?" >> "$log"
    """
    let job: [String: Any] = [
        "Label": "com.domasgru.sparklespike.relaunch",
        "ProgramArguments": ["/bin/sh", "-c", script, "relaunch", "\(getpid())", path, oldVersion],
        "RunAtLoad": true,
        "LaunchOnlyOnce": true,
        "EnableTransactions": false,
        "ProcessType": "Interactive",
    ]
    var auth: AuthorizationRef?
    guard AuthorizationCreate(nil, nil, [], &auth) == errSecSuccess, let auth else {
        log("no authorization"); return
    }
    defer { AuthorizationFree(auth, []) }
    var removeError: Unmanaged<CFError>?
    _ = SMJobRemove(kSMDomainUserLaunchd, "com.domasgru.sparklespike.relaunch" as CFString, auth, true, &removeError)
    var error: Unmanaged<CFError>?
    let done = SMJobSubmit(kSMDomainUserLaunchd, job as CFDictionary, auth, &error)
    log("relauncher submitted: \(done) \(error?.takeRetainedValue().localizedDescription ?? "")")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let driver = SilentDriver()
    let delegate = Delegate()
    var updater: SPUUpdater?

    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        log("willFinishLaunching args=\(CommandLine.arguments.dropFirst()) event=\(event.map { "\($0.eventClass) \($0.eventID)" } ?? "nil") front=\(frontmost())")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        let propData = event?.paramDescriptor(forKeyword: keyAEPropData)
        let parent = getppid()
        log("didFinishLaunching event=\(event.map { "\($0.eventClass) \($0.eventID)" } ?? "nil") propData=\(propData?.description ?? "nil") isDefault=\(notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] ?? "nil") parent=\(parent) active=\(NSApp.isActive) policy=\(NSApp.activationPolicy().rawValue) front=\(frontmost())")

        var headers = ["Accept-Language": "en"]
        var encoding: String?
        if FileManager.default.fileExists(atPath: "\(runDir)/no-cookies") {
            HTTPCookieStorage.shared.cookieAcceptPolicy = .never
            log("cookie policy set to never")
            encoding = "gzip"
        }

        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: delegate)
        if let encoding { headers["Accept-Encoding"] = encoding }
        updater.userAgentString = "TrackpadLauncher"
        updater.httpHeaders = headers
        self.updater = updater
        do {
            try updater.start()
            log("started automaticChecks=\(updater.automaticallyChecksForUpdates) automaticDownloads=\(updater.automaticallyDownloadsUpdates) interval=\(updater.updateCheckInterval) canCheck=\(updater.canCheckForUpdates)")
            updater.checkForUpdatesInBackground()
        } catch {
            log("start failed \(error)")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            log("one second in: active=\(NSApp.isActive) front=\(frontmost())")
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let event = NSAppleEventManager.shared().currentAppleEvent
        let sourcePid = event?.attributeDescriptor(forKeyword: keySenderPIDAttr)?.int32Value ?? 0
        let reason = event?.attributeDescriptor(forKeyword: kAEQuitReason)?.enumCodeValue ?? 0
        log("shouldTerminate event=\(event.map { "\($0.eventClass) \($0.eventID)" } ?? "nil") senderPid=\(sourcePid) quitReason=\(reason)")
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) { log("willTerminate") }
}

@main
struct Main {
    static func main() {
        let app = NSApplication.shared
        let appDelegate = AppDelegate()
        app.delegate = appDelegate
        app.run()
    }
}
