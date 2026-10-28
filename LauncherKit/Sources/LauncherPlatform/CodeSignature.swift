import Foundation
import LauncherCore
import Security

/// Whether a bundle or binary is signed for release, by the Developer ID requirement: an Apple-anchored chain with the
/// Developer ID intermediate and the Developer ID Application leaf markers.
public enum CodeSignature {
    private static let developerID =
        "anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"

    /// A build not signed for release reads as `.release` when `arguments` hold `--as-release-build` (exact match), so
    /// the move and the login rules can be checked by hand without a Developer ID certificate; a release build ignores
    /// the argument.
    public static func buildOfThisProcess(arguments: [String]) -> Build {
        var me: SecCode?
        if SecCodeCopySelf([], &me) == errSecSuccess, let me, let requirement = requirement(),
            SecCodeCheckValidity(me, [], requirement) == errSecSuccess
        {
            return .release
        }
        return arguments.contains("--as-release-build") ? .release : .development
    }

    /// Unsigned or unreadable reads as `.development`. Resources are not validated: a bundle edited after signing is
    /// still signed with a Developer ID.
    static func build(of url: URL) -> Build {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
            let requirement = requirement(), SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSDoNotValidateResources), requirement) == errSecSuccess
        else { return .development }
        return .release
    }

    private static func requirement() -> SecRequirement? {
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(developerID as CFString, [], &requirement) == errSecSuccess else { return nil }
        return requirement
    }
}
