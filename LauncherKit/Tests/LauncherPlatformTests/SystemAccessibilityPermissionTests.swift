import Foundation
import LauncherCore
import Synchronization
import Testing
import notify

@testable import LauncherPlatform

@MainActor @Suite struct SystemAccessibilityPermissionTests {
    /// True when `onChange` ran within `seconds` of `action`; the push is awaited, never polled.
    private func changeArrives(
        on adapter: SystemAccessibilityPermission, within seconds: Int, after action: () -> Void
    ) async -> Bool {
        let outcome = AsyncStream<Bool>.makeStream()
        adapter.onChange = { outcome.continuation.yield(true) }
        let bound = Task {
            try await Task.sleep(for: .seconds(seconds))
            outcome.continuation.yield(false)
        }
        action()
        var iterator = outcome.stream.makeAsyncIterator()
        let arrived = await iterator.next() ?? false
        bound.cancel()
        adapter.onChange = nil
        return arrived
    }

    @Test func broadcastReachesOnChangeOnlyWhenTrustChanged() async {
        let flag = Mutex(false)
        let adapter = SystemAccessibilityPermission(trusted: { flag.withLock { $0 } })
        #expect(!adapter.isGranted())

        let noise = await changeArrives(on: adapter, within: 1) {
            notify_post(SystemAccessibilityPermission.changeNotification)
        }
        #expect(!noise, "a broadcast without a trust change stays silent")

        let granted = await changeArrives(on: adapter, within: 5) {
            flag.withLock { $0 = true }
            notify_post(SystemAccessibilityPermission.changeNotification)
        }
        #expect(granted, "onChange arrives within 5 s of a grant")
        #expect(adapter.isGranted())

        let revoked = await changeArrives(on: adapter, within: 5) {
            flag.withLock { $0 = false }
            notify_post(SystemAccessibilityPermission.changeNotification)
        }
        #expect(revoked, "onChange arrives within 5 s of a revoke")
        #expect(!adapter.isGranted())
    }
}
