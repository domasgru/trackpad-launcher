// Check (after fan-out): does `notarized` still pass with kSecCSNoNetworkAccess on a STAPLED notarised app, and does
// it fail on an UNSTAPLED notarised app (so the flag really keeps the check offline)? Candidate 1 rests on this.
// Usage: swift nonetwork-notarized.swift <app> [<app> ...]. Reads only.
import Foundation
import Security

for path in CommandLine.arguments.dropFirst() {
    var staticCode: SecStaticCode?
    guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &staticCode) == errSecSuccess,
          let code = staticCode else { print(path, "cannot create static code"); continue }
    var req: SecRequirement?
    SecRequirementCreateWithString("notarized" as CFString, [], &req)
    let base = kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode
    let online = SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: base), req)
    let offline = SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: base | (1 << 29)), req)
    print(path, "notarized with network:", online, " with kSecCSNoNetworkAccess:", offline)
}
