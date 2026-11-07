import Foundation
import ServiceManagement

/// `SMJob` lives in this file and nowhere else. Deprecated since 10.10, and the only way to submit a non-permanent job:
/// Sparkle's own comment says so, and it shares this API's fate.
enum LaunchdJob {
    /// Waits until launchd has removed the job. False when there was none.
    @discardableResult
    static func remove(label: String) -> Bool {
        guard let authorization = authorization() else { return false }
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

    private static func authorization() -> AuthorizationRef? {
        var authorization: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &authorization) == errSecSuccess else { return nil }
        return authorization
    }
}
