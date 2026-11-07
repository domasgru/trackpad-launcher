// What CodeSignature.isGenuine costs on a real stapled app, with its exact flags and requirement.
// Decides whether the check may run on the main actor.
import Foundation
import Security

let app = CommandLine.arguments[1]
let team = CommandLine.arguments[2]
let identifier = CommandLine.arguments[3]
let text = "anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"\(team)\" and identifier \"\(identifier)\" and notarized"
var requirement: SecRequirement?
precondition(SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess)
let noNetwork: UInt32 = 1 << 29
let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | noNetwork)

for round in 1...6 {
    var code: SecStaticCode?
    let start = ContinuousClock.now
    precondition(SecStaticCodeCreateWithPath(URL(fileURLWithPath: app) as CFURL, [], &code) == errSecSuccess)
    let status = SecStaticCodeCheckValidity(code!, flags, requirement)
    let took = ContinuousClock.now - start
    print("round \(round): status \(status), \(took)")
}
