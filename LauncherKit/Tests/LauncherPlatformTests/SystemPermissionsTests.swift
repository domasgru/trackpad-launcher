import Foundation
import LauncherCore
import Synchronization
import Testing
import notify

@testable import LauncherPlatform

@MainActor @Suite struct SystemPermissionsTests {
    /// True when `onChange` ran within `seconds` of `action`; the push is awaited, never polled.
    private func changeArrives(
        on adapter: SystemPermissions, within seconds: Int, after action: () -> Void
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
        let adapter = SystemPermissions(trusted: { flag.withLock { $0 } })
        #expect(!adapter.isGranted(.accessibility))

        let noise = await changeArrives(on: adapter, within: 1) {
            notify_post(SystemPermissions.changeNotification)
        }
        #expect(!noise, "a broadcast without a trust change stays silent")

        let granted = await changeArrives(on: adapter, within: 5) {
            flag.withLock { $0 = true }
            notify_post(SystemPermissions.changeNotification)
        }
        #expect(granted, "onChange arrives within 5 s of a grant")
        #expect(adapter.isGranted(.accessibility))

        let revoked = await changeArrives(on: adapter, within: 5) {
            flag.withLock { $0 = false }
            notify_post(SystemPermissions.changeNotification)
        }
        #expect(revoked, "onChange arrives within 5 s of a revoke")
        #expect(!adapter.isGranted(.accessibility))
    }
}
