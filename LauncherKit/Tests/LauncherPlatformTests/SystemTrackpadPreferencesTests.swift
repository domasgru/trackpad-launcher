import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

/// The real adapter against throwaway cfprefs domains written by a child process, the way System Settings writes.
@MainActor @Suite struct SystemTrackpadPreferencesTests {
    /// Deletes the domain in teardown even if an expectation fails.
    final class Domain: Sendable {
        let name: String
        init(_ kind: TrackpadKind) { name = "tl.test.\(UUID().uuidString).\(kind)" }
        deinit { Self.defaults(["delete", name]) }

        func write(_ key: String, int value: Int) { Self.defaults(["write", name, key, "-int", "\(value)"]) }
        func delete() { Self.defaults(["delete", name]) }

        static func defaults(_ arguments: [String]) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            process.arguments = arguments
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }

    /// True when `onChange` ran before the 5 s bound; the push is awaited, never polled.
    private func changeArrives(on adapter: SystemTrackpadPreferences, after action: () -> Void) async -> Bool {
        let outcome = AsyncStream<Bool>.makeStream()
        adapter.onChange = { outcome.continuation.yield(true) }
        let bound = Task {
            try await Task.sleep(for: .seconds(5))
            outcome.continuation.yield(false)
        }
        action()
        var iterator = outcome.stream.makeAsyncIterator()
        let arrived = await iterator.next() ?? false
        bound.cancel()
        adapter.onChange = nil
        return arrived
    }

    @Test(arguments: TrackpadKind.allCases)
    func tapToClickWriteAndDeleteArePushedAndReadable(kind: TrackpadKind) async {
        let domain = Domain(kind)
        domain.write("Unrelated", int: 1)
        let adapter = SystemTrackpadPreferences(domains: [kind: domain.name])
        #expect(adapter.current()[kind]?[.tapToClick] == nil)

        let wrote = await changeArrives(on: adapter) { domain.write("Clicking", int: 1) }
        #expect(wrote, "onChange arrives within 5 s of the write")
        #expect(adapter.current()[kind]?[.tapToClick] == 1)
        #expect(adapter.current()[kind]?[.lookUpTapWithThreeFingers] == nil)

        let deleted = await changeArrives(on: adapter) { domain.delete() }
        #expect(deleted, "onChange arrives within 5 s of the delete")
        #expect(adapter.current()[kind]?[.tapToClick] == nil)
    }

    @Test(arguments: TrackpadKind.allCases)
    func lookUpWithThreeFingersIsReadAsTwo(kind: TrackpadKind) async {
        let domain = Domain(kind)
        domain.write("Unrelated", int: 1)
        let adapter = SystemTrackpadPreferences(domains: [kind: domain.name])

        let wrote = await changeArrives(on: adapter) { domain.write("TrackpadThreeFingerTapGesture", int: 2) }

        #expect(wrote)
        #expect(adapter.current()[kind]?[.lookUpTapWithThreeFingers] == 2)
    }
}
