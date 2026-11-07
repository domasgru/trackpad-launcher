import Foundation
import ServiceManagement

/// `SMJob` lives in this file and nowhere else. Deprecated since 10.10, and the only way to submit a non-permanent job:
/// Sparkle's own comment says so, and it shares this API's fate.
enum LaunchdJob {
    /// Waits until launchd has removed the job. False when there was none.
    @discardableResult
    static func remove(label: String) -> Bool {
        // SMJobRemove answers true for a label that was never loaded, so the job is looked up first.
        guard SMJobCopyDictionary(kSMDomainUserLaunchd, label as CFString) != nil,
            let authorization = authorization()
        else { return false }
        defer { AuthorizationFree(authorization, []) }
        var error: Unmanaged<CFError>?
        let removed = SMJobRemove(kSMDomainUserLaunchd, label as CFString, authorization, true, &error)
        error?.release()
        return removed
    }

    /// Removes any stale job of this label first.
    @discardableResult
    static func submit(label: String, arguments: [String]) -> Bool {
        guard let authorization = authorization() else { return false }
        defer { AuthorizationFree(authorization, []) }
        var staleError: Unmanaged<CFError>?
        _ = SMJobRemove(kSMDomainUserLaunchd, label as CFString, authorization, true, &staleError)
        staleError?.release()
        let job: [String: Any] = [
            "Label": label,
            "ProgramArguments": arguments,
            "RunAtLoad": true,
            "LaunchOnlyOnce": true,
            "EnableTransactions": false,
            "ProcessType": "Interactive",
        ]
        var error: Unmanaged<CFError>?
        let submitted = SMJobSubmit(kSMDomainUserLaunchd, job as CFDictionary, authorization, &error)
        error?.release()
        return submitted
    }

    /// The hand-over job. `allowed` is 5 s in production; a test passes its own, and a stub for `open`.
    static func handOverArguments(oldPID: Int32, bundle: URL, build: String, allowed: Int, open: String) -> [String] {
        ["/bin/sh", "-c", handOverScript, "handover", String(oldPID), bundle.path, build, String(allowed), open]
    }

    /// Runs in launchd after the old process has ended. The wait is bounded on wall time, not on rounds: a loop that
    /// counted its sleeps took 7.4 s for an intended 5. The version is compared as text, so nothing here couples to
    /// Sparkle.
    static let handOverScript = """
        # launchd: /bin/sh -c "$script" handover <pid> <bundle> <build> <allowed> <open>
        old=$1; bundle=$2; build=$3; allowed=$4; open=$5
        # Never open while the old process lives: it would only show its window. It ends in this same turn; if it hangs, the
        # wait holds until it goes, so a late end still installs and still comes back.
        while /bin/kill -0 "$old" 2>/dev/null; do /bin/sleep 0.05; done
        gone=$(/bin/date +%s)
        while [ $(( $(/bin/date +%s) - gone )) -le "$allowed" ]; do
          now=$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$bundle/Contents/Info.plist" 2>/dev/null)
          if [ -n "$now" ] && [ "$now" != "$build" ]; then break; fi
          /bin/sleep 0.1
        done
        exec "$open" -g -a "$bundle" --args --after-update
        """

    private static func authorization()-> AuthorizationRef? {
        var authorization: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &authorization) == errSecSuccess else { return nil }
        return authorization
    }
}
