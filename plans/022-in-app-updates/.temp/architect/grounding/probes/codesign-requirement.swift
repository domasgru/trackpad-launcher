// Probe: can the Security framework check, for an app bundle on disk, all of R8's conditions:
// signed with a given Developer ID team, notarised, a given bundle identifier, a given version?
// Claims tested:
//  (a) SecRequirementCreateWithString accepts the `notarized` keyword;
//  (b) a notarised Developer ID app passes `anchor apple generic and certificate leaf[subject.OU] = TEAM
//      and identifier ID and notarized`, and fails with a wrong team or identifier;
//  (c) an ad-hoc signed bundle fails the `notarized` requirement;
//  (d) the signing information exposes the team identifier and the Info.plist version.
// Usage: swift codesign-requirement.swift <app path> [<app path> ...]
// Reads only; changes nothing.
import Foundation
import Security

func check(_ path: String) {
    print("== \(path)")
    var staticCode: SecStaticCode?
    guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &staticCode) == errSecSuccess,
          let code = staticCode else { print("cannot create static code"); return }
    var info: CFDictionary?
    SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info)
    let dict = (info as? [String: Any]) ?? [:]
    let team = dict[kSecCodeInfoTeamIdentifier as String] as? String
    let ident = dict[kSecCodeInfoIdentifier as String] as? String
    let plist = dict[kSecCodeInfoPList as String] as? [String: Any]
    print("team:", team ?? "nil", "identifier:", ident ?? "nil",
          "version:", plist?["CFBundleShortVersionString"] as? String ?? "nil",
          "LSMinimumSystemVersion:", plist?["LSMinimumSystemVersion"] as? String ?? "nil")
    let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
    var reqs = [
        "notarized",
        "anchor apple generic and certificate leaf[subject.OU] = \"\(team ?? "NONE")\" and identifier \"\(ident ?? "")\" and notarized",
        "anchor apple generic and certificate leaf[subject.OU] = \"WRONGTEAM1\" and identifier \"\(ident ?? "")\" and notarized",
        "anchor apple generic and certificate leaf[subject.OU] = \"\(team ?? "NONE")\" and identifier \"wrong.identifier\" and notarized",
    ]
    // Developer ID leaf + intermediate markers, as Apple's TN for Developer ID checks.
    reqs.append("anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"\(team ?? "NONE")\"")
    for r in reqs {
        var req: SecRequirement?
        let cs = SecRequirementCreateWithString(r as CFString, [], &req)
        guard cs == errSecSuccess, let req else { print("requirement did not parse (\(cs)):", r); continue }
        let t0 = Date()
        let status = SecStaticCodeCheckValidity(code, flags, req)
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        print(String(format: "%6d", status), "\(ms) ms", r)
    }
}

for path in CommandLine.arguments.dropFirst() { check(path) }
