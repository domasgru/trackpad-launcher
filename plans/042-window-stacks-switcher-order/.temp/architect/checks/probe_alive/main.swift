// Check 3 (after fan-out): the cheapest way to tell whether remembered window numbers still exist.
// (a) Cost of CGWindowListCopyWindowInfo(optionAll) (descriptions of every window), for reference.
// (b) Cost of CGWindowListCreate(optionAll) (numbers only, every owner) and how many numbers it holds.
// (c) Cost of CGWindowListCreateDescriptionFromArray for three numbers; does it drop a closed window's number and keep a
//     minimised one's?
// Usage: probe_alive <path to compiled fixture>. Terminates the fixture at the end.
import AppKit

setvbuf(stdout, nil, _IONBF, 0)

let fixture = Process()
fixture.executableURL = URL(fileURLWithPath: CommandLine.arguments[1])
let toFixture = Pipe()
let fromFixture = Pipe()
fixture.standardInput = toFixture
fixture.standardOutput = fromFixture
try! fixture.run()
var buffer = ""
func line() -> String {
    while true {
        if let range = buffer.range(of: "\n") {
            let found = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            return found
        }
        buffer += String(decoding: fromFixture.fileHandleForReading.availableData, as: UTF8.self)
    }
}
func send(_ command: String) -> String {
    toFixture.fileHandleForWriting.write((command + "\n").data(using: .utf8)!)
    return line()
}
let ready = line()
print("fixture:", ready)
func number(_ title: String) -> UInt32 {
    let part = ready.split(separator: " ").first { $0.hasPrefix(title + "=") }!
    return UInt32(part.split(separator: "=")[1])!
}
let w1 = number("W1"), w2 = number("W2"), w3 = number("W3")

func timed(_ label: String, rounds: Int = 50, _ body: () -> Int) {
    _ = body()
    let start = now()
    var size = 0
    for _ in 0..<rounds { size = body() }
    print("  \(label): \(ms((now() - start) / Double(rounds))) per call, \(size) entries")
}
print("== costs, warm, averaged over 50 calls")
timed("(a) CGWindowListCopyWindowInfo(optionAll) descriptions") {
    (CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]])?.count ?? -1
}
// (b) CGWindowListCreate is unavailable in Swift ("No replacement at present"): not an option.
func alive(_ numbers: [UInt32]) -> [UInt32] {
    // A CFArray of raw CGWindowID values, made with null callbacks, as the call expects.
    var values = numbers.map { UnsafeRawPointer(bitPattern: UInt($0)) }
    let array = values.withUnsafeMutableBufferPointer { buffer in
        CFArrayCreate(nil, UnsafeMutablePointer(mutating: buffer.baseAddress!).withMemoryRebound(to: UnsafeRawPointer?.self, capacity: buffer.count) { $0 }, buffer.count, nil)
    }
    let described = CGWindowListCreateDescriptionFromArray(array) as? [[String: Any]] ?? []
    return described.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
}
timed("(c) CGWindowListCreateDescriptionFromArray for 3 numbers") { alive([w1, w2, w3]).count }

print("\n== does (c) follow closes and minimised windows? W3 starts minimised")
print("  alive before closing W2: \(alive([w1, w2, w3]))  (W1=\(w1) W2=\(w2) W3=\(w3))")
print("  close W2 ->", send("close W2"))
RunLoop.current.run(until: Date().addingTimeInterval(0.5))
print("  alive after closing W2:  \(alive([w1, w2, w3]))")
print("fixture:", send("quit"))
fixture.waitUntilExit()
