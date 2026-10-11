// Probe: does a plist-encoded Settings record saved by today's build decode once Settings gains a new stored
// property with a default value? Shows false if synthesized Codable tolerates a missing key.
// Mirrors Settings.swift: `handMode` and `assignments: [Gesture: AssignedApp]` with Gesture an Int enum that is
// CodingKeyRepresentable, then a new `switcherList: [AssignedApp]` added with `= []`.
import Foundation

enum Gesture: Int, CaseIterable, Codable, CodingKeyRepresentable { case one = 1, two, three, four }
enum GestureNew: Int, CaseIterable, Codable, CodingKeyRepresentable { case one = 1, two, three, four, five }
struct AssignedApp: Codable, Equatable { let bundleID: String; let name: String; let lastKnownURL: URL }

struct Old: Codable { var handMode = "right"; var assignments: [Gesture: AssignedApp] = [:] }
struct NewSynthesized: Codable {
    var handMode = "right"; var assignments: [GestureNew: AssignedApp] = [:]; var switcherList: [AssignedApp] = []
}
struct NewTolerant: Codable {
    var handMode = "right"; var assignments: [GestureNew: AssignedApp] = [:]; var switcherList: [AssignedApp] = []
    init() {}
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        handMode = try c.decode(String.self, forKey: .handMode)
        assignments = try c.decode([GestureNew: AssignedApp].self, forKey: .assignments)
        switcherList = try c.decodeIfPresent([AssignedApp].self, forKey: .switcherList) ?? []
    }
}

let arc = AssignedApp(bundleID: "company.thebrowser.Browser", name: "Arc", lastKnownURL: URL(filePath: "/Applications/Arc.app"))
var old = Old(); old.assignments[.two] = arc
let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
let data = try encoder.encode(old)
print("old record bytes: \(data.count)")
do {
    let decoded = try PropertyListDecoder().decode(NewSynthesized.self, from: data)
    print("SYNTHESIZED decodes: assignments=\(decoded.assignments.count) switcherList=\(decoded.switcherList.count)")
} catch {
    print("SYNTHESIZED throws: \(error)")
}
do {
    let decoded = try PropertyListDecoder().decode(NewTolerant.self, from: data)
    print("TOLERANT decodes: handMode=\(decoded.handMode) two=\(decoded.assignments[.two]?.name ?? "nil") switcherList=\(decoded.switcherList.count)")
} catch {
    print("TOLERANT throws: \(error)")
}
// Round trip of the new shape, so the tolerant init does not break saving.
var fresh = NewTolerant(); fresh.assignments[.five] = arc; fresh.switcherList = [arc, arc]
let again = try PropertyListDecoder().decode(NewTolerant.self, from: try encoder.encode(fresh))
print("NEW round trip: five=\(again.assignments[.five]?.name ?? "nil") switcherList=\(again.switcherList.map(\.name))")
