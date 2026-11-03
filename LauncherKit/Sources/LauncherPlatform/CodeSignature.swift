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

    /// Who signed this process, when the signature truly is a Developer ID: the team and identifier an update must match.
    /// It takes no arguments, so `--as-release-build` cannot fake it. nil for Xcode, Debug, the perf build, ad hoc.
    public static func developerIDSigner() -> Signer? {
        var me: SecCode?
        guard SecCodeCopySelf([], &me) == errSecSuccess, let me, let requirement = requirement(),
            SecCodeCheckValidity(me, [], requirement) == errSecSuccess
        else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(me, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        return signer(of: staticCode)
    }

    /// The same rule for a bundle on disk. Resources are not validated, as in `build(of:)`.
    static func developerIDSigner(of bundle: URL) -> Signer? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundle as CFURL, [], &code) == errSecSuccess, let code,
            let requirement = requirement(),
            SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSDoNotValidateResources), requirement) == errSecSuccess
        else { return nil }
        return signer(of: code)
    }

    /// Whether a downloaded bundle is the release the card offered: the Developer ID requirement with this copy's team
    /// and identifier and Apple's notarisation, checked with strict validation of every architecture, nested code and
    /// resource, reading the stapled ticket rather than asking the network; and its sealed Info.plist names exactly
    /// `release.version` and `release.minimumMacOS`.
    static func isGenuine(_ bundle: URL, as release: Release, signer: Signer) -> Bool {
        let quoted = CharacterSet(charactersIn: "\"\\")
        guard signer.team.rangeOfCharacter(from: quoted) == nil, signer.identifier.rangeOfCharacter(from: quoted) == nil
        else { return false }
        let text =
            "\(developerID) and certificate leaf[subject.OU] = \"\(signer.team)\" and identifier \"\(signer.identifier)\" and notarized"
        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(bundle as CFURL, [], &code) == errSecSuccess, let code,
            SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess, let requirement
        else { return false }
        // kSecCSNoNetworkAccess (1 << 29) is not imported into Swift.
        let noNetworkAccess: UInt32 = 1 << 29
        let strict = SecCSFlags(
            rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | noNetworkAccess)
        guard SecStaticCodeCheckValidity(code, strict, requirement) == errSecSuccess else { return false }
        guard let values = signingInformation(of: code),
            let plist = values[kSecCodeInfoPList as String] as? [String: Any],
            let version = (plist["CFBundleShortVersionString"] as? String).flatMap(Version.init),
            let minimum = (plist["LSMinimumSystemVersion"] as? String).flatMap(Version.init)
        else { return false }
        return version == release.version && minimum == release.minimumMacOS
    }

    private static func signingInformation(of code: SecStaticCode) -> [String: Any]? {
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess
        else { return nil }
        return information as? [String: Any]
    }

    private static func signer(of code: SecStaticCode) -> Signer? {
        guard let values = signingInformation(of: code),
            let team = values[kSecCodeInfoTeamIdentifier as String] as? String,
            let identifier = values[kSecCodeInfoIdentifier as String] as? String
        else { return nil }
        return Signer(team: team, identifier: identifier)
    }

    private static func requirement() -> SecRequirement? {
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(developerID as CFString, [], &requirement) == errSecSuccess else { return nil }
        return requirement
    }
}

/// The team and bundle identifier a Developer ID signature carries.
public struct Signer: Sendable, Equatable {
    public let team: String
    public let identifier: String
}
