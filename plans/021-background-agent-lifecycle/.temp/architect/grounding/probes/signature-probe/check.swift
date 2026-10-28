// Plan 021 R23 probe: does the Developer ID code-signing requirement tell a release build apart from an Apple
// Development build and an ad-hoc build, both for a bundle on disk and for the running process itself?
// Usage: check <bundle-or-binary> ...   (also checks itself last via SecCodeCopySelf)
import Foundation
import Security

// Apple's documented Developer ID Application requirement: Apple-anchored chain, the Developer ID intermediate
// marker (1.2.840.113635.100.6.2.6) and the Developer ID Application leaf marker (1.2.840.113635.100.6.1.13).
let developerID = "anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"

var requirement: SecRequirement?
guard SecRequirementCreateWithString(developerID as CFString, [], &requirement) == errSecSuccess, let requirement else {
    print("requirement did not parse"); exit(1)
}

for path in CommandLine.arguments.dropFirst() {
    var code: SecStaticCode?
    let created = SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &code)
    guard created == errSecSuccess, let code else { print("\(path): SecStaticCodeCreateWithPath \(created)"); continue }
    let status = SecStaticCodeCheckValidity(code, [], requirement)
    print("\(path): developerID=\(status == errSecSuccess) (OSStatus \(status))")
}

var me: SecCode?
if SecCodeCopySelf([], &me) == errSecSuccess, let me {
    let status = SecCodeCheckValidity(me, [], requirement)
    print("self (\(CommandLine.arguments[0])): developerID=\(status == errSecSuccess) (OSStatus \(status))")
}
